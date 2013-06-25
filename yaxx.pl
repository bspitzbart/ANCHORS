#!/usr/bin/env perl

use warnings;

=begin comment
To Do
- Use IO::All instead of File::chdir, spec, slurp, copy
- Check with make_fake that real data have been processed successfully
- More reasonable binning strategy
- Put error bars on net counts
- Clean up parameters and param names 
- Source detection (wavdetect?)
- Improved source list, use wavdetect fits source file
- Fix underscore in customize vars / format vars?
- Remove -force or do an audit to see if it is honored everywhere
- Bigger backgrounds
- Object names (???)
- dmcoords for ra,dec (?? probably not)
- Better plotting of ungrouped data
- Name resolution?
- Use depends in get_data_files
- Check for CIAO environment
- Write out local yaxx_info file at end
- Make DS9 start only once (?)  (iconify?)

X Make sure param paths can be relative (processing one obsid makes next fail)
X Change log_file to log_dir (NOT DONE), and make sure it is created if needed (DONE)
X Improve tabspec (automatically find correct limits given energy range)
X Filter before ds9_image
X Use Config::General

Source/objlist structure:

If (exists object list) {
  Use command line args to filter object list
  If no source number, assume 0 (1?)
  if no RA
} else {
  If (command line args defined) {
    
yaxx              # Targets for all obsids in data dir (default)
yaxx -src 3       # Source 3 (wav then celldetect)
yaxx -obsid 800
yaxx -objlist blah # All in <blah>
yaxx -objlist blah [-obsid <obsid>] [-srcid <srcid>] # Filter <blah> by obsid srcid


- Starting point is an object list
- Command line 

=cut

# Load various packages
use POSIX qw(strftime strtod);
use Data::Dumper;
use Cwd;
use English;
use File::Copy;
use File::Basename;
use File::Path;
use File::Glob;
use File::Find;
use File::Slurp;
use File::Spec;
use File::Spec::Link;
use Config::General;
use Hash::Merge;

# 'Local' packages (not on CPAN)
use RDB;
use Ska::Process qw(message get_params);
use Ska::IO qw(read_ascii);
use CFITSIO::Simple;

$SIG{INT} = \&clean_up;		# Make sur to clean up if ctrl-c is pressed

# Read in options.  First Yaxx defaults, then parameter file, then user-spec'd config file
%par     = get_options_and_init();	# Yaxx param and command line options, start up messages
%def_cfg = ParseConfig(-ConfigFile => "$par{program_dir}/$par{config_file}");
%usr_cfg = ParseConfig(-ConfigFile => $par{config_file});	# User-spec'd Yaxx config options 

# Create a temporary location for parameter files which is local to this process
make_param_dir();

# Load the YaxxSource module
require "$par{program_dir}/YaxxSource.pl";

$objlist = get_object_list();	# Read optional list of specific objects for fitting
@obsid = get_obsids($objlist);	# Extract the list of obsids

OBSID: foreach $obsid (@obsid) {
    # Using the input_dir parameter, discover where the input data live
    chdir $par{CWD};
    $input_dir = get_input_dir($par{input_dir}, $obsid) or next OBSID;

    chdir $par{output_dir};
    $cwd = cwd;   # par{output_dir} may be a link, so use this to get true directory

    # Make the global list of sources for this obsid (includes all ccdids),
    # and use these values to initialize YaxxSource objects.
    @source = map { new YaxxSource(\%def_cfg, \%usr_cfg, \%par, $_) }
                 get_sources($input_dir, $obsid, $objlist);

    # Skip obsid if no sources were returned or if there is an IGNORE
    # file present for this obsid
    next OBSID if (@source == 0 or -e $source[0]->file('ignore_obs', $cwd));

    # If doing a summary, just extract relevant information and go to the next Obsid
    next OBSID if ($par{summary} and do_summary(\@summary, \@source));

    # Generate XPIPE info file if requested
    next OBSID if ($par{xpipe_info} and do_xpipe_info(\@xpipe_info, \@source));

    # Do V&V of field (show report) for each source
    if ($par{vv}) {
	map { $_->validate() if $_->{process} } @source;
	next OBSID;
    }

    # Make fake dataset (i.e. set of fake src directories) for each source
    if ($par{make_fake}) {
	foreach $source (grep $_->{process}, @source) {
	    $source->gunzip;
	    $source->make_fakes($par{make_fake});
	    $source->gzip;
	}
	next OBSID;
    }

    # Try to find or create source region data for every source, using either XPIPE
    # values or existing region file definitions.  
    foreach $source (@source) { 
	$source->get_src_reg($cwd);
    }
    # Instead of the part above, make a new function to generate a list of known 
    # source regions that need to be avoided.  Pass this to make_reg_files.

    # Now the real work for each source to be processed
    # 
    # make_dirs:      	 Make ccdid and src subdirectories (if necessary)
    # get_data_files: 	 Get evt and aoff files and make local copies    
    # get_info:          Get auxillary information
    # make_reg_files: 	 Make src, bkg, and chip region files
    # run_psextract:     Use psextract to generate PI, RMF and ARF files
    # group_pi_file:     Group (bin) PI file
    # make_images:       Use ds9 to make images of source events and regions
    # set_gal_nh:        Get the galactic NH for source
    # set_models:        Set models for sherpa fitting from $models hash
    # sherpa_fit:        Do the actual fitting with Sherpa
    # make_report:       Make latex/postscript report summarizing the fitting

    foreach $source (grep $_->{process}, @source) {
        while ($source->next_instance()) {
	    chdir $par{output_dir};
	    next if (-e $source->file('ignore_src')); # Skip if IGNORE file is present in src dir

	    my $fake = $source->{fakeid} ? "fakeid=$source->{fakeid}" : '';

	    message("\n" .
		    "************************************************************************\n" .
 		    "***  Obsid=$source->{obsid} ccdid=$source->{ccdid} srcid=$source->{srcid} $fake\n" .
	            "************************************************************************\n");
	    message('', time=>1);

	    next if $par{dryrun};
	
	    if (($ok = $source->make_dirs) and $source->fast_check and $source->get_lock ) {
		$ok = (
		       $source->open_log()              and
		       $source->gunzip()                and
		       $source->clean($par{preclean})   and
		       $source->get_data_files          and
		       $source->set_info                and
		       $source->make_reg_files(@source) and
#		       chdir here? 
		       $source->run_psextract           and
		       $source->set_pi_info             and
		       $source->group_pi_file           and
		       $source->make_images             and
		       $source->set_gal_nh              and
		       $source->sherpa_fit              and
		       $source->make_report             and
		       $source->clean($par{clean})      and
		       $source->gzip()                  and
		       $source->release_lock()
		      );
	    }

	    message(($ok ? "*** SUCCESS" : "*** FAILURE") .
		    " for Obsid=$source->{obsid} ccdid=$source->{ccdid} srcid=$source->{srcid} $fake\n",
		    time=>1);
	    $source->close_log();
	}
    }
}

write_summary(\@summary) if ($par{summary});
write_xpipe_info(\@xpipe_info) if ($par{xpipe_info});
clean_up();

##****************************************************************************
sub clean_up {
##****************************************************************************
    my $sig = shift;
    YaxxSource::stop_ds9();	# Stop any instance of ds9 that yaxx created
    make_param_dir('clean');	# Clean the temp (local) CIAO param dir
    die "Stopped because of signal $sig\n" if $sig;
}
    
##****************************************************************************
sub do_summary {
# 
# Call YaxxSource functions to generate summary of Sherpa fit data for
# each specified source 
##****************************************************************************
    my $summary = shift;
    my @source = @{ shift(@_) };
    local $_;

    foreach my $source (grep $_->{process}, @source) {
	while ($source->next_instance()) {
	    my $summ = $source->summary($par{summary});
	    if ($summ) {
		my $fake = $source->{fakeid} ? "fakeid=$source->{fakeid}" : '';
		message("Generated summary for Obsid=$source->{obsid} ccdid=$source->{ccdid} ".
			"srcid=$source->{srcid} $fake\n");
		push @{$summary}, $summ;
	    }
	}
    }
    return 1;
}

##****************************************************************************
sub do_xpipe_info {
#
# Call YaxxSource function to collect useful information from XPIPE source file
##****************************************************************************
    my $xpipe_info = shift;
    my @source = @{ shift(@_) };
    local $_;

    my $info;
    foreach (grep $_->{process}, @source) {
	push @{$xpipe_info}, $info if ($info = $_->xpipe_info());
    }

    return 1;
}

##****************************************************************************
sub get_input_dir {
##****************************************************************************
    my ($format, $obsid) = @_;
    my $input_dir = sprintf($format, $obsid);
    if ($input_dir =~ /[*?]/) {  # input_dir is a glob.  Try to resolve it
	my @dirs = glob($input_dir);
	if (@dirs != 1) {
	    message("ERROR - ". scalar @dirs ." input data directories match $input_dir\n");
	    return;
	}
	$input_dir = $dirs[0];
    }
    return File::Spec->rel2abs($input_dir);
}

##****************************************************************************
sub get_sources {
# Get all the sources for a particular object list
##****************************************************************************
    my ($dir, $obsid, $objlist) = @_;
    my @source = ();
    my %files;

    return get_xpipe_sources(@_) if $par{xpipe};

    # If not processing XPIPE files, then just do a simple filter of objlist
    # (which must exist in this case) by obsid, ccdid, srcid
    foreach (@{$objlist}) {
	next unless $_->{obsid} == $obsid;
	next if (defined $par{ccdid} and $_->{ccdid} != $par{ccdid});
	next if (defined $par{srcid} and $_->{srcid} != $par{srcid});
	$_->{redshift} = 0.0 unless defined $_->{redshift};
	$_->{process} = 1;
	$_->{input_dir} = $dir;
	push @source, $_;
    }
    return @source;
}

##****************************************************************************
sub get_xpipe_sources {
# Get all the sources in an XPIPE data directory 
# for a particular obsid.  Filter the list by either a specified list of 
# objects or by $par{min_counts}
##****************************************************************************
    my ($dir, $obsid, $objlist) = @_;
    my @source = ();
    my %files;

    # For XPIPE processing, read sources from source_prop_ccdid* files
    opendir(DIR, $dir);
    map { $files{"$dir/$_"} = $1 if /source_prop_ccdid(\d+)_B\.out2/ } readdir(DIR);
    closedir(DIR);

    unless (keys %files) {
	message("ERROR - Could not find any source properties file for ObsID=$obsid\n");
	return;
    }

    while (($source_file, $ccdid) = each %files) {
	next if (defined $par{ccdid} and $ccdid != $par{ccdid});

	open SOURCE, '< '.$source_file or
	  do { message("ERROR - could not open '$source_file': $!"); return };

	# first line has energy band, obsid, ccdid
	my $header = <SOURCE>;
	my %params = map { split '=', $_, 2 } split '[\s;]+', $header;

	# filter on energy band for this source_prop file
	do { message("ERROR - Energy band is '$params{energyband}', not 'B'\n"); return }
	  unless ($params{energyband} eq 'B');
	close SOURCE;

	# Need to predefine column names because the data file includes only
	# a non-parseable version (names split over two lines)
	@cols = qw(srcid rad X  Y   ra   dec  net_B  err_B  SNR  net_S
		   net_H  HR  rate_B flux_B  B_src B_bkg  area mean_ea_src mean_ea_bkg 
		   nearby_src_src nearby_src_bkg);
	
	my @tmp_source = read_ascii($source_file,
				    include => '^\s*[0-9]',
				    cols    => \@cols);

	foreach (@tmp_source) {
	    $_->{ccdid} = $ccdid;
	    $_->{obsid} = $obsid;
	    $_->{rad}   *= 2.0;	# Convert from arcsec to ACIS pixels
	}
		
	push @source, @tmp_source;
    }

    # Define a redshift, which might be overridden later with a real value
    map { $_->{object} = sprintf("XS%05dB%d_%03d", $_->{obsid}, $_->{ccdid}, $_->{srcid});
	  $_->{redshift} = 0.0;
	  $_->{process} = 1;
          $_->{input_dir} = $dir } @source;

    # Filter the final source list.  If an object list was provided, then cross-correlate
    # the two lists.  Otherwise, do a cut on net broadband counts.  

    if ($objlist) {
	# Cross correlate source list (from XPIPE file) with object list (user specified RDB file)
	# based on obsid, ccdid, and srcid
	# This should be cleaned up using hashes etc
	my $i;
	foreach $i (0..$#source) {
	    my @match = grep { $obsid == $_->{obsid} 
			       and $source[$i]->{ccdid} == $_->{ccdid} 
			       and $source[$i]->{srcid} == $_->{srcid} } @{$objlist};
	    if (@match == 0) {
		$source[$i]->{process} = 0;
	    } elsif (@match == 1) {
		%{$source[$i]} = (%{$source[$i]}, %{$match[0]}); # Copy match into source[$i]
	    } elsif (@match > 1) {
		message("ERROR - multiple matches in object list for " .
			"source $source[$i]->{srcid} ($obsid $ccdid)\n");
		return;
	    }
	}
    } else {
	# filter on net_B
	map { $_->{process} = 0 if ($_->{net_B} < $par{min_counts}) } @source;
    }
    
    # Final filtering on command line parms ccdid and srcid
    map { $_->{process} = 0 if ($_->{ccdid} != $par{ccdid}) } @source if (defined $par{ccdid});
    map { $_->{process} = 0 if ($_->{srcid} != $par{srcid}) } @source if (defined $par{srcid});

    return @source;
}

##****************************************************************************
sub get_options_and_init {
##****************************************************************************
    my ($program_name) = fileparse($PROGRAM_NAME, qr{\.pl});

    my %par = get_params("${program_name}.par",
			 "force!",
			 "fit!",
			 "lock!", # Pay attention to lock file
			 "obsid=s",
			 "ccdid=i",
			 "srcid=i",
			 "objlist=s",
			 "summary=s",
			 "make_fake=i",
			 "process_fake!",
			 "vv!",
			 "xpipe_info=s", # Write out RDB with info for objlist
			);

    die "Error - No program parameters found\n" unless (%par);

    $| = 1;			# Set stdout flushing
    delete $ENV{UPARM};		# Get rid of possible UPARM variable for get_param()

    $par{program_dir} = dirname(File::Spec->rel2abs(File::Spec::Link->resolve($PROGRAM_NAME)));

    # These can be independent directories, but preferred setup is within yaxx
    $par{corr_arf_dir} = "$par{program_dir}/corrarf" unless defined $par{corr_arf_dir};
    $par{slang_dir} = "$par{program_dir}/slang"      unless defined $par{slang_dir};
    $par{bkg_mdl_prefix} = "$par{program_dir}/background_model/"  unless defined $par{bkg_mdl_prefix};
    $ENV{SLANG_SCRIPT_PATH} = join ":", $par{slang_dir}, $ENV{SLANG_SCRIPT_PATH};
    $par{config_file} = "${program_name}.cfg";

    $par{output_dir} = File::Spec->rel2abs($par{output_dir}); 
    $par{cmd_file} = File::Spec->rel2abs($par{cmd_file});

    # Make a unique log file name, and create log directory if needed
    if ($par{log_file} and $par{log_file} =~ /\/$/) {
	-d $par{log_file} or
	  mkdir $par{log_file} or die "Could not make log file dir $par{log_file}";
	$par{log_file} .= strftime("%Y-%m-%d_%H:%M", localtime);
    }

    $par{CWD} = cwd;
    map {$_ = lc} $par{spec_chan_type};
    
    # Initialize the message routine
    message('', (init     => 1,
		 log_file => $par{log_file},
		 stdout   => $par{loud},
		 time_format => "*** %Y-%b-%d %H:%M:%S\n"
		 ) );

    # Print out the parameters
    if ($par{loud}) {
	message("COMMAND LINE PARAMETERS\n", time => 1);
	foreach (sort keys %par) {
	    message(sprintf("  %-16s = %s\n", $_, $par{$_}));
	}
	message("\n", %par);
    }

    message("\n** WARNING - it appears that FTOOLS (LHEASOFT) is loaded.  This\n" .
	    "            will likely cause problems in psextract\n\n")
      if ($ENV{LHEA_DATA} or $ENV{LHEA_HELP} or $ENV{LHEAPERL});

    return %par;
}


##****************************************************************************
sub get_obsids {
##****************************************************************************
    my $objlist = shift;
    my $file;

    # if $par{obsid} is numbers and whitespace, assume it's a list of obsids

    my @obsid = split ' ', $par{obsid} if ($par{obsid} and $par{obsid} =~ /^[\s\d]+$/);

    # if an object list was supplied, use that to define the list of obsids,
    # unless some obsids were already defined using $par{obsid}.  In this case,
    # take the intersection of the lists

    if ($objlist) {
	my %objlist_obsid = map { $_->{obsid} => 1 } @{$objlist};
	if (@obsid) {
	    my @index = grep { exists $objlist_obsid{$obsid[$_]} } (0..$#obsid);
	    @obsid = @obsid[@index];
	} else {
	    @obsid = keys %objlist_obsid;
	}
    }

    message("Processing following obsids: @obsid\n", %par);

    return @obsid;
}


##****************************************************************************
sub get_object_list {
##****************************************************************************
    my %data;
    our $objlist;
    local $_;

    return unless $par{objlist};

    # Check if the argument is a readable file
    my $rdb = new RDB $par{objlist} or die "ERROR - Couldn't read object list $par{objlist}\n";

    while ( $rdb->read( \%data ) ) {
	# Check if there is an XPIPE-type identifier e.g. XS00918B2_011
	if ($data{xray_id} =~ /XS(\d+)B(\d+)_(\d+)/i) {
	    $data{obsid} = $1 + 0;
	    $data{ccdid} = $2 + 0;
	    $data{srcid} = $3 + 0;
	} else {
	    # Otherwise look for obsid, ccdid, srcid and clean them up
	    map {$_ = sprintf("%d",$_) if defined $_} @data{qw(obsid ccdid srcid)};
	    die "ERROR - need an 'obsid' column in object list '$par{objlist}'\n"
	      unless (defined $data{obsid});
	}
	push @{$objlist}, { %data };
    }
    $rdb->close;
    return $objlist;
}

##****************************************************************************
sub write_summary {
##****************************************************************************
    my $summ = shift;
    my $s;
    local $_;
    my @col;		# Ordered list of columns from summary->{cols}
    my %col;		# Hash of columns from summary->{cols}
    my @col_all;	# Final ordered list of columns
    my %col_all;	# Hash of cols from summary->{data} (includes upper/lower limit cols)
    my %data;

    # Find all the columns.  {data} hash may have additional upper and lower limit cols
    foreach $s (@{$summ}) {
	foreach (@{$s->{cols}}) {
	    push @col, $_ unless ($col{$_});
	    $col{$_} = 1;
	}
	map {$col_all{$_} = 1} (keys %{$s->{data}});
    }
    
    # Now
    foreach $c (@col) {
	push @col_all, $c;
	push @col_all, "$c.up" if $col_all{"$c.up"};
	push @col_all, "$c.low" if $col_all{"$c.low"};
    }

    # collect the data into the structures for writing to FITS file
    foreach $c (@col_all) {
	foreach $s (@{$summ}) {
	    push @{$data{$c}}, defined ($s->{data}->{$c}) ? $s->{data}->{$c} : -999;
	}
    }

    $ok = fits_write_bintbl("$par{CWD}/summ_$par{summary}.fits", %data, {col_names => \@col_all});
    message("Wrote summary for model $par{summary} to summ_$par{summary}.fits\n");
}

##****************************************************************************
sub write_xpipe_info {
##****************************************************************************
    my $xpipe_info = shift;
    my $xpipe_info_file = File::Spec->rel2abs($par{xpipe_info}, $par{CWD});
    print "Writing xpipe info to $par{xpipe_info} ($xpipe_info_file)\n";

    my @cols = @{$def_cfg{xpipe_info_cols}};
    write_rdb($xpipe_info_file, $xpipe_info, @cols)
      if (@cols);
}

##****************************************************************************
sub write_rdb {
##****************************************************************************
    my ($file, $data, @cols) = @_;
    my $unused_chars;
    my $col_data;
    my $data_out;
    my %type;
    my ($col, $i);
    local $_;

    # Figure out if its a hash of arrays or array of hashes
    my $hoa = (ref($data) eq 'HASH');

    # If cols are not supplied, use keys from data or first element (if not hoa)
    unless (@cols) {
	@cols = $hoa ? keys %{$data} : keys %{$data->[0]};
    }

    # Figure out number of data elements.  NO checking done for ill formed data
    my $n_data = $hoa ? @{$data->{$cols[0]}} : @{$data};

    # Figure out data type and length for each column
    foreach $col (@cols) {
	my $max_len = 0;
	my $could_be_double = 1;

	foreach $i (0 .. $n_data-1) {
	    $_ = $hoa ? $data->{$col}[$i] : $data->[$i]{$col};
	    unless (defined $_) {
		message("Undefined data for col $col and row $i\n");
		last;
	    }
	    $max_len = length if (length > $max_len);

	    if ($could_be_double) {
		(undef, $unused_chars) = strtod($_);
		next if ($unused_chars == 0);

		$could_be_double = 0;
		last;
	    }
	}
	$type{$col} = $could_be_double ? "${max_len}N" : "${max_len}S";
    }

    my $rdb = new RDB;
    $rdb->open($file, ">") or print STDERR "write_rdb: Could not open $file for writing\n";
    $rdb->init( map {$_ => $type{$_}} @cols );
	    
    foreach $i (0 .. $n_data-1) {
	$data_out = $hoa ? {map { $_ => $data->{$_}[$i] } @cols} : $data->[$i];
	$rdb->write($data_out);
    }

    $rdb->close();

    1;
}

##****************************************************************************
sub make_param_dir {
##****************************************************************************
    my $clean = shift;

    my @pfiles = split ';', $ENV{PFILES};
    die "PFILES env variable is empty" unless @pfiles;

    if ($clean) {
	my $dir = $pfiles[0];
	my @files = glob "$dir/*";
	unlink @files if @files;
	rmdir $dir or die "Failed to clean temporary param dir $dir: $!";
	return;
    }
    
    my $dir = cwd() . "/cxcds_param_$PROCESS_ID";
    mkdir $dir or die "Could not make parameter file dir $dir: $!";
    $ENV{PFILES} = join ';', ($dir, $pfiles[-1]);
}
