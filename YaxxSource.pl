package YaxxSource;

use warnings;

# 'Local' CXC packages
use Ska::Process qw(message run_tool make_local_copy);
use Ska::Convert qw(dec2hms);
use CFITSIO::Simple;
use Chandra::Tools::dmcoords;

# Available on CPAN
use Image::DS9;
use Decision::Depends;
use Data::Dumper;
use POSIX qw(tmpnam strtod);
use Carp;
use File::Basename;
use File::Spec;
use File::Slurp;
use File::Copy;
use File::chdir;
use Cwd;
use English;
use Storable qw(dclone);
use Config::General;
use Hash::Merge qw(merge);
use Switch;

our %model_format;
our $NAN = (-1)**0.5;		# Generate a NaN 
Hash::Merge::set_behavior( RIGHT_PRECEDENT );

# Global variables to allow persistent ds9 instance
our $ds9;			# Image::DS9 object
our $ds9_pid;			# Running ds9 process id
our $ds9_filehandle;		# DS9 filehandle (used to start ds9)

##****************************************************************************
sub new {
##****************************************************************************
    my $classname = shift;
    my $self = {};
    bless ($self);
    local $_;

    # Merge the default config, project config, and source info hashes into $self
    map { %{$self} = %{merge($self, $_)} } @_;
    $self->{base_dir} = cwd;

    # Merge info from yaxx_info (written by yaxx in source dir at end of 
    # processing) and user_info (defined by user in source dir)
    my $yaxx_info = $self->file('yaxx_info');
    my $user_info = dirname($yaxx_info) . "/$self->{config_file}";
    foreach ($yaxx_info, $user_info) {
	%{$self} = %{merge( $self, {ParseConfig(-ConfigFile => $_)} )} if -e;
    }

    # Set special "override" values from <xpipe_vals> for xpipe processing
    if ($self->{xpipe}) {
	foreach (keys %{$self->{xpipe_vals} }) {
	    $self->{$_} = $self->customize_string($self->{xpipe_vals}{$_});
	}
    }

    return $self;
}

##****************************************************************************
sub make_dirs {
##****************************************************************************
    my $self = shift;

    my $src_dir = dirname $self->file('src');
    my $status = system("mkdir -p $src_dir"); # Create directories if needed.
    # Doesn't complain if they already exist
    do { message("ERROR - Could not create directory $src_dir\n"); return }
      if $status;

    1;
}

##****************************************************************************
sub clean {
##****************************************************************************
    my $self = shift;
    my $type_list = shift;
    local $_;
    return 1 unless $type_list;

    if ($type_list eq 'all') {
	$type_list = join ' ', qw(ccdid_evt2 evt2 obsid_asol asol
				  pi pi_bin rmf arf bg_pi bg_rmf bg_arf
				  asphist validated
				  report log);
    }

    my ($type, $mdl, $tmp, @clean);
    my $src_dir = dirname $self->file('src');

    foreach $type (split ' ', $type_list) {
	if ($type eq 'fit') {
	    foreach $mdl (map {basename $_,'.mdl'} glob("$src_dir/*.mdl")) {
		push @clean, map {"$src_dir/$mdl.$_"} qw(mdl in ps unc proj);
	    }
	} elsif ($type eq 'report') {
	    push @clean, glob($self->file('report')."*");
	} elsif ($type eq 'log') {
	    push @clean, glob($self->file('log').".*");
	} elsif ($type eq 'region') {
	    push @clean, glob("$src_dir/*.reg");
	} elsif ($type eq 'extract') {
	    push @clean, map {$self->file($_)} qw(arf asphist pi pi_bin bg_pi rmf);
	} elsif ($type eq 'fake' and $self->{fakeid}) {
	    push @clean, glob("$src_dir/*");
	} elsif ($file = $self->file($type)) {
	    push @clean, $file;
	} else {
	    message("WARNING - Unknown file type '$type' for cleaning\n");
	}
    }
    if (@clean) {
	message("Cleaning files:\n   " . join("\n   ",@clean) . "\n");
	map {unlink if (-e or -l)} @clean;
    }

    1;
}

##****************************************************************************
sub get_lock {
##****************************************************************************
    my $self = shift;
    my $msg;

    return 1 unless $self->{lock};

    my $lock_file = $self->file('lock');
    my $date = gmtime();

    if (-r $lock_file) {
	$msg = read_file($lock_file);
	message($msg);
	return;
    } else {
	$msg = "Source locked by $ENV{USER} at $date by process $PROCESS_ID on $ENV{HOST}\n";
	write_file($lock_file, $msg);
    }

    return 1;
}

##****************************************************************************
sub release_lock {
##****************************************************************************
    my $self = shift;

    my $lock_file = $self->file('lock');
    return ((-w $lock_file and unlink $lock_file) or not $self->{lock});
}

##****************************************************************************
sub gunzip {
# just a wrapper for gzip
##****************************************************************************
    my $self = shift;
    return $self->gzip(1);
}

##****************************************************************************
sub gzip {
##****************************************************************************
    my $self = shift;
    my $unzip = shift;		# If a second arg is passed, then unzip 
    local $_;
    my @files;

    # Carry on if unzipping or gzip option set.  Else return success.
    return 1 unless ($unzip or $self->{gzip});

    my $gz = ($unzip ? '.gz' : '');
    my $gzip = ($unzip ? 'gunzip' : 'gzip');

    my $src_dir = dirname $self->file('src');

    # Gzip/gunzip *.mdl ds9_image pi pi_in, and report[_group].ps
    # Don't bother with arf and rmf because they are already reasonably compact
    @files = map { $self->file('report', {ext => ".ps$gz", group => $_}) }
      keys %{$self->{report}{group}};

    push @files, glob("$src_dir/*.mdl$gz");
    foreach (qw(ds9_image pi pi_bin)) {
	push @files, $self->file($_, {ext => $gz});
    }

    # Compress or uncompress each file if it exists
    map { system("$gzip -f $_") if (-e $_ and not -l $_) } @files;

    return 1;
}

##****************************************************************************
sub set_info {
##****************************************************************************
    my $self = shift;
    local $_;

    # Define source name, RA, Dec from evt2 file if not already defined
    unless (defined $self->{object} and defined $self->{ra} and defined $self->{dec}) {
	my $hdr = fits_read_hdr($self->file('evt2'), 'events');
	$self->{object} = $hdr->{OBJECT} unless (defined $self->{object});
	$self->{ra} = $hdr->{RA_TARG} unless (defined $self->{ra});
	$self->{dec} = $hdr->{DEC_TARG} unless (defined $self->{dec});
    }
    
    1;
}
	
########################################################################################
# Validate each source by displaying report.ps
# 
sub validate {
########################################################################################
    my $self = shift;
    return if (-e $self->file('ignore_src') or -e $self->file('ignore_obs')
	      or -e $self->file('validated'));
    ($report) = glob $self->file('report') . ".ps*";
    return unless $report;
    my $pid = open(GV, "gv $report |") or die "Could not spawn 'gv $report'\n";
    print $self->{xray_id}, ": ";
    my $a = <STDIN>;
    if ($a =~ /\A[a-z]/i) {
	write_file($self->file('ignore_src'), $a);
    } else {
	write_file($self->file('validated'), $a);
    }	
	  
    kill 9 => $pid;
    sleep 1;
    close GV;

    return 1;
}


########################################################################################
sub get_data_files {
########################################################################################
    my $self = shift;
    my $cwd = cwd;
    local $_;
    my @files;

    my $identify = "obsid=$self->{obsid} ccdid=$self->{ccdid} srcid=$self->{srcid}";
    
    # Go through globs one at a time, looking for matching files
    foreach (split ' ',$self->{evt2_glob}) {
	last if (@files = glob "$self->{input_dir}/$_");
    }

    # Make sure we got one and only one event file
    if (@files > 1 or @files == 0) {
	my $err = @files ? 'too many' : 'no';
	message("ERROR - $err input event files '$self->{evt2_glob}' for $identify\n");
	return;
    } 

    # Make a local unzipped copy of the event file in the yaxx directory.  If the
    # event file in the database is already unzipped, then just link to it
    # Return an absolute (full) filename

    make_local_copy($files[0], $self->file('ccdid_evt2'), {force => $self->{force}}); 
    make_local_copy($self->file('ccdid_evt2'), $self->file('evt2'), {force => $self->{force}});
    
    # Now find the aspect asol/aoff files for the obsid
    foreach (split ' ',$self->{asol_glob}) {
	last if (@files = glob "$self->{input_dir}/$_");
    }

    # Find the aspect offset file and make a local unzipped copy in obsid directory
    my $obsid_asol = $self->file('obsid_asol');
    if (@files == 0) {
	message("ERROR - no input AOFF/ASOL files for $identify\n");
	return;
    } elsif (@files == 1) {
	make_local_copy($files[0], $obsid_asol, {force => $self->{force}}); # One per obsid
    } else {
        # Run dmmerge if necessary
	# Delete existing file (to force rebuild) if it is older than any of the input files

	if ($self->{force} or test_dep(-target => $obsid_asol, -depend => \@files)) {
	    # Multiple files, need to merge them
	    my $list = join ',', @files;

	    run_tool("dmmerge",
		     infile => $list,
		     columnList => '',
		     outfile => $self->file('obsid_asol'),
		     outBlock => '',
		     clobber => 'yes',
		     lookupTab => '/soft/ciao/data/dmmerge_header_lookup.txt',
		     { timeout => $self->{timeout},
		       paste => 1,
		     }
		    ) or return;
	}
    }

    # Make a local linked copy in the source directory
    make_local_copy($self->file('obsid_asol'), $self->file('asol'), {force => $self->{force}}); 

    return (-e $self->file('asol') and -e $self->file('evt2')); # actual success?
} 

##****************************************************************************
sub file {
#
# Encapsulate all the naming conventions here
#
##****************************************************************************
    my ($self, $type, $opt) = @_;
    $cwd = $opt->{cwd} || cwd;
    return { %{$self->{file_definition}} } if ($type eq '%file_def');

    my $f = $self->{file_definition}{$type} or die "ERROR - invalid file type '$type' detected\n";

    # Define special directory name for src:  src<srcid> for real sources
    # and src<srcid>/fak/<fakeid>  for fake sources
    my $src_dirname = "src$self->{srcid}";
    $src_dirname .= "/fak/$self->{fakeid}" if $self->{fakeid};

    $f =~ s/OBSID/obs$self->{obsid}/;
    $f =~ s/CCDID/$self->{ccd_dirname}/;
    $f =~ s/CCDNUM/$self->{ccdid}/;
    $f =~ s/SRCID/$src_dirname/;
    $f .= "_$opt->{group}" if (defined $opt->{group} && $opt->{group} ne 'ALL_MODELS');
    $f .= $opt->{ext} if $opt->{ext};
    
    return File::Spec->abs2rel("$self->{base_dir}/$f", $cwd);
}

##****************************************************************************
sub get_src_reg {
#
# Determine the extraction region for this source.  By default, the values from
# the XPIPE source properties file are used.  But if there is a src.reg file
# in the Yaxx source directory, parse it and look for the first circle or ellipse
# and use this instead.
#
##****************************************************************************
    my $self = shift;
    my $cwd = shift;
    my $src_file = $self->file('src', {cwd => $cwd});
    my $RE_Float = qr/[+-]?(?:\d+[.]?\d*|[.]\d+)(?:[dDeE][+-]?\d+)?/;

    # Look for a customized version
    if (-r $src_file) {
	open SRC, "$src_file" or do {
	    message("ERROR - could not open src region file $src_file\n");
	    return;
	};
	while (<SRC>) {
	    if ( / (circle|ellipse|annulus|rotbox) ( \( [^()]+ \) ) /ix) {
		$self->{src_reg} = "$1$2";
		($self->{X}, $self->{Y}) = ($1,$2) if ($2 =~ /($RE_Float) \s* , \s* ($RE_Float)/x);
		last;  
	    }
	}
	close SRC;
	do {message("ERROR - Could not find circle, ellipse or annulus in region file $src_file\n"); return}
	  unless $self->{src_reg};
    } else {
	# Don't continue unless the source X,Y have been defined
	unless (defined $self->{X} and defined $self->{Y}) {
	    message("ERROR - no src file $src_file and no source coordinate X,Y defined\n");
	    return;
	}

	# Define the default source extraction region
	$self->{rad} = $self->{min_src_rad} if $self->{rad} < $self->{min_src_rad};
	$self->{src_reg} = sprintf "circle(%.2f,%.2f,%.2f)", $self->{X}, $self->{Y}, $self->{rad};
    }

    1;				# Success
}

##****************************************************************************
sub make_reg_files {
##****************************************************************************
    my $self = shift;
    my @source = @_;

    my $src_file = $self->file('src');
    my $bkg_file = $self->file('bkg');
    my $evt2     = $self->file('evt2');
    
    return 1 if (-r $src_file and -r $bkg_file);

    message("Running dmcoords for $evt2\n");
    my $dmcoord = new Chandra::Tools::dmcoords $evt2;
    $dmcoord->set( chip => "acis-$self->{ccdid}" );
    my @out = $dmcoord->coords( chip => (1,1),
				chip => (1,1024),
				chip => (1024,1024),
				chip => (1024,1) );
    $self->{chip_reg} = sprintf("polygon(%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f)",
				$out[0]->{sky}->{x},$out[0]->{sky}->{'y'},
				$out[1]->{sky}->{x},$out[1]->{sky}->{'y'},
				$out[2]->{sky}->{x},$out[2]->{sky}->{'y'},
				$out[3]->{sky}->{x},$out[3]->{sky}->{'y'});

    unless (-r $src_file) {
	message("Creating src.reg for source $self->{srcid}\n");
	open SRC, "> $src_file" or do {
	    message("ERROR - could not open src region $src_file\n");
	    return;
	};
	print SRC "# Region file format: DS9 version 3.0\n";
	print SRC "$self->{chip_reg} & $self->{src_reg}\n";
	close SRC;
    }

    unless (-r $bkg_file) {
	open BKG, "> $bkg_file" or do {
	    message("ERROR - could not open bkg region $bkg_file\n");
	    return;
	};
	print BKG "# Region file format: DS9 version 3.0\n";
	printf BKG ("$self->{chip_reg} & annulus(%.2f,%.2f,%.2f,%.2f)\n",
		    $self->{X}, $self->{Y}, $self->{rad} + $self->{bgd_ann_sep},
		    $self->{rad} + $self->{bgd_ann_sep} + $self->{bgd_ann_wid});
	map { print BKG "-$_->{src_reg}\n" } @source;
	close BKG;
    }

    1;
}

##****************************************************************************
sub run_psextract {
##****************************************************************************
# 
#  Run psextract to extract PI file
#
##****************************************************************************
    my $self = shift;
    local $_;
    my %file;

    chdir dirname($self->file('evt2'));

    # Check for required input files
    foreach (qw(src bkg evt2 asol)) {
	$file{$_} = $self->file($_);
	unless (-e $file{$_}) {
	    message("ERROR - missing $_ file $file{$_}\n");
	    return;
	}
    }
 
    # Set up to check dependencies and return success if already met
    my @target  = map { $self->file($_) } qw(pi rmf arf bg_pi asphist);
    my @test_dep = (-target => \@target, -depend => [values %file]);

    return 1 unless test_dep(@test_dep);

    # Delete any existing psextract output files
    my @psfiles = map { $self->file($_) } qw(pi rmf arf bg_pi bg_rmf bg_arf asphist);
    map {unlink if -e} @psfiles; # Clean all psextract files first

    # Define filtered source and background files
    my $energy = "energy=$self->{min_energy}:$self->{max_energy}";
    my $time_filter = ($self->{event_start_time} and $self->{event_stop_time}) ?
		       "\[time=$self->{event_start_time}:$self->{event_stop_time}\]" : '';
    my $src_evts_energy = "\"$file{evt2}\[sky=region($file{src})\]${time_filter}\[$energy\]\"";
    my $src_evts 	= "\"$file{evt2}\[sky=region($file{src})\]${time_filter}\"";
    my $bkg_evts 	= "\"$file{evt2}\[sky=region($file{bkg})\]${time_filter}\"";
	
    # Make sure there are some counts in source region
    if (get_evt_counts($src_evts_energy) < 1) {
	message("ERROR - no counts in source region\n");
	return;
    }

    # Now actually run psextract to extract the spectrum
    run_tool("punlearn dmgroup");
    run_tool("psextract",
	     events   => $src_evts,
	     bgevents => $bkg_evts,
	     root     => $self->file('root'),
	     asol     => $file{asol}, 
	     bgasol   => "",
	     ptype    => "pi",
	     gtype    => "NONE",
	     gspec    => $self->{bin_counts},
	     verbose  => 2,
	     clobber  => "yes",
	     {
	      timeout => $self->{timeout}, 
	      paste => 1,
	     }
	    );

    # Make sure all dependencies are now satisfied
    if (test_dep(@test_dep)) {
	message("ERROR - did not create all files in psextract\n");
	return;
    }

    1;
}

##****************************************************************************
sub get_evt_counts {
#
# Return the number of counts in the (filtered) event file using 
# dmlist <file> counts
#
##****************************************************************************
    my $evt = shift;
    my $tmp = POSIX::tmpnam;
    run_tool('dmlist',
	     infile => $evt,
	     opt    => 'counts',
	     outfile=> $tmp,
	     { loud => 1 }
	    );
    chomp (my $counts = read_file($tmp));
    unlink $tmp;
    return $counts;
}

##****************************************************************************
sub group_pi_file {
##****************************************************************************
    my $self = shift;
    local $_;

    my $pi = $self->file('pi');
    my $pi_bin = $self->file('pi_bin');
    my @test_dep = (-target => $pi_bin, -depend => $pi);
    my $bin_size = sprintf "%d", $self->{counts}/$self->{max_bins};
    $bin_size = $self->{bin_counts} if $bin_size < $self->{bin_counts};
    
    return 1 unless test_dep(@test_dep);

    my $tabspec = get_tabspec($self->file('arf'), $self->{min_energy}, $self->{max_energy});

    unlink $pi_bin if (-e $pi_bin);
    run_tool("dmgroup",
	     infile => $pi,     # Input datafile specification
	     outfile => $pi_bin, # Output datafile specification
	     grouptype => 'NUM_CTS', #          Grouping type
	     grouptypeval => $bin_size, #  Grouping type value
	     binspec => '""',	#        Binning specification (file or list)
#	     tabspec => "'$self->{tabspec}'", # Ignore rows 
	     tabspec => "'$tabspec'", # Ignore rows 
	     tabcolumn => 'PI',	# Column for ignoring rows
	     xcolumn => 'PI',	#          Name of column to bin on
	     ycolumn => 'COUNTS', #          Name of column to bin on
	     {
	      timeout => $self->{timeout},
	      paste => 1,
	     }
	    );

    if (test_dep(@test_dep)) {
	message("ERROR - did not create all files in dmgroup\n");
	return;
    }

    1;
}


##****************************************************************************
sub get_tabspec {
##****************************************************************************
    my $arf = shift;
    my $min_energy = shift;
    my $max_energy = shift;
    local $_;

    my %arf = fits_read_bintbl($arf);
    my $ok = PDL::which($arf{energ_lo} > $min_energy/1000);
    my $min_spec = ($ok->nelem > 0) ? sprintf(":%d:#1", $ok->at(0)+1) : '';
    $ok = PDL::which($arf{energ_hi} < $max_energy/1000);
    my $max_spec = ($ok->nelem > 0) ? sprintf("%d::#1", $ok->at(-1)+1) : '';

    return join(',', $min_spec, $max_spec);
}

##****************************************************************************
sub make_images {
##****************************************************************************
    my $self = shift;
    local $_;

    # Skip images if this is a fake dataset
    return 1 if ($self->{fakeid} or $self->{no_ds9});

    # Define various file names for use later
    my $image_file = File::Spec->rel2abs($self->file('ds9_image'));
    my $evt = File::Spec->rel2abs($self->file('evt2'));
    my $src = $self->file('src');
    my $bkg = $self->file('bkg');
    my $all_reg = File::Spec->rel2abs($self->file('all_reg'));
    my @target = ($image_file);
    my @test_dep = (-target => \@target, -depend => [$all_reg, $evt, $src, $bkg]);

    # Check on dependencies 
    return 1 unless ($self->{force} or test_dep(@test_dep));
    map {unlink if -e} (@target);  # Clean target files

    return 1 if $ds9_failed;	# Already tried and failed to start ds9

    # Make a new ds9 object if not already created (this var is global to package)
    unless (defined $ds9) {
	$ds9 = Image::DS9->new( { Server => "Yaxx_DS9_$PID" }) ;
	while ( $ds9->nservers ) {
	    message("Waiting for a chance to run ds9\n");
	    sleep 1;
	}
    }

    unless (defined $ds9_pid) {
	message("Starting ds9...\n");
	my $geometry = $self->{ds9_geom} || "617x728-0+0";
	$ds9_pid = open $ds9_filehandle, "ds9 -geometry $geometry -title Yaxx_DS9_$PID 2>&1 |";
	$ds9->wait(30) or do {
	    message("ERROR - Could not start ds9\n");
	    $ds9_failed = 1;
	    return 1;		# Can still do other processing without ds9
	};
    }

    # Define commands to print a small image of source counts.  Use absolute filenames
    # since we have no idea where ds9 was started
    my $x = sprintf("%d", $self->{X});
    my $y = sprintf("%d", $self->{Y});
    my @reg;

    # Parse default (or user-defined) commands from config file for making image
    my @ds9_cmds = split "\n", $self->customize_string($self->{ds9_cmds});
    foreach (@ds9_cmds) {
	chomp;
	my ($dx, $dy, $label);
	if (($dx,$dy,$label) = /_YAXX_LABEL_ \s* \( ([^,]+) ,  ([^,]+) , ([^)]+) \)/x) {
	    my $label_x = ($dx =~ /[+-]/) ? $x + $dx : $dx;
	    my $label_y = ($dy =~ /[+-]/) ? $y + $dy : $dy;
	    $_ = "text $label_x $label_y # $label";
	} 
    }

    # Parse the src and bkg region files and build the DS9-format region specifiers
    # for all regions.  Then put them in the 'all_reg' file.
    push @reg, "# Region file format: DS9 version 3.0\n";
    push @reg, "global color=black\n";
    $_ = read_file($src);
    while (m{ -? \s* \w+ \( [^()]+ \) }xg) { push @reg, "$MATCH\n"; }
    $_ = read_file($bkg);
    while (m{ -? \s* 
	      ( \w+ \( [^()]+ \) )
	    }xg) {
	push @reg, "$MATCH\n" unless $1 eq $self->{src_reg};
    }
    write_file($all_reg, @reg);

    $ds9->zoom(to => 1);
    $ds9->file("$evt");
    $ds9->bin(factor => 16);
    $ds9->bin(filter => "{energy > $self->{min_energy}}");
    $ds9->bin(filter => "{energy < $self->{max_energy}}");
    $ds9->pan(to => ($x,$y), "physical");
    $ds9->bin(factor => 1);
    $ds9->print(destination => 'file');
    $ds9->print(filename => $image_file);

    # Default or user-defined commands to set zoom, scale, colormap, and label(s)
    foreach (@ds9_cmds) {
	# couldn't get "Set("regions text ...") to work, so look for 'text' cmd
	# which must actually be a regions command from above
	next unless /\S/;
	/^text/ ? $ds9->regions($_) : $ds9->Set($_);  
    }

    $ds9->regions(load => $all_reg);
    $ds9->print();

    # Close down ds9 each time if desired
    stop_ds9() if ($self->{kill_ds9});

    if (test_dep(@test_dep)) {
	message("ERROR - failed to make ds9 image\n");
	return;
    }

    1;
}

##****************************************************************************
sub start_ds9 {
#
# This code looks orphaned...
#
##****************************************************************************
    my $ds9 = Image::DS9->new( { Server => 'ImageDS9', verbose => $verbose });
    unless ( $ds9->nservers )
      {
	  system( "ds9 -title ImageDS9 &" );
	  $ds9->wait() or do {
	      message("Unable to connect to DS9\n" );
	      return;
	  }
      }
   
    $ds9->raise();
    $ds9;
}

##****************************************************************************
sub stop_ds9 {
##****************************************************************************
    if (defined $ds9_pid) {
	kill 9 => $ds9_pid;
	message("Killed ds9 pid=$ds9_pid\n");
	sleep 4;
	undef $ds9_pid;
    }
    if (defined $ds9_filehandle) {
	close $ds9_filehandle;
	undef $ds9_filehandle;
    }
    undef $ds9;
}
 
##****************************************************************************
sub get_event_files {
    ##****************************************************************************
    my $dir = shift;
    my $obsid = shift;
    my $objlist = shift;

    my $file;
    my %evt2;
    my @files = glob "$dir/evt2_ccdid?.fits*";

    # map evt2 event lists to their chip ids, filtering on both $par{ccdid}
    # and a list of specific objects
    for $file (@files) {
	# Parse the CCDID from file name and make sure file is readable
	if ($file =~ /evt2_ccdid(\d)\.fits/ and -r $file) {
	    my $ccdid = $1;

	    # Skip if a ccdid filter is defined and match fails
	    # next if (defined $par{ccdid} and $ccdid != $par{ccdid});

	    # If a list of objects is defined, make sure obsid and ccdid matches
	    # for at least one source
	    if ($objlist) {
		next unless grep { $obsid == $_->{obsid} and $ccdid == $_->{ccdid} } @{$objlist};
	    }

	    # Passed all the filters, so add hash element
	    $evt2{$ccdid} = $file;
	}
    }

    return %evt2;
}


##****************************************************************************
sub set_gal_nh {
#
# Get galactic N_H for source RA,Dec and set $self->{gal_nh}
##****************************************************************************
    my $self = shift;
    return 1 if (defined $self->{gal_nh});  # Already set via info file
    local $_;

    # Try to get gal_nh from existing mdl.in file (faster)
    my $src_dir = dirname $self->file('src');
    if (my @mdl_files = glob "$src_dir/*.in") {
	foreach (@mdl_files) {
	    my $lines = read_file $_;
	    if ($lines =~ /\b gal\.nh \s* = \s* (\S+)/x) {
		$self->{gal_nh} = $1;
		return 1;
	    }
	}
    }

    my $tmp1 = POSIX::tmpnam;
    my $tmp2 = POSIX::tmpnam;

    my ($ra_hms, $dec_hms) = dec2hms($self->{ra}, $self->{dec});
    $ra_hms =~ s/:/ /g;
    $dec_hms =~ s/:/ /g;
    
    my $cmd = "prop_colden_exe d nrao f j2000 :$tmp1:$tmp2 > /dev/null";

    open IN, "> $tmp1";
    print IN "$ra_hms $dec_hms\n";
    close IN;
    
    system $cmd;

    open OUT, "$tmp2" or die "ERROR - Colden did not create expected output file\n";
    while (<OUT>) {
	my @vals = split;
	next unless (@vals >= 9 and $vals[6] =~ /^[-0-9\.]+$/ and $vals[7] =~ /^[-0-9\.]+$/);
	if ($vals[8] eq '-') {message("ERROR - Colden did not give valid NH\n"); return}
	$self->{gal_nh} = $vals[8] / 100.0; # Convert from units of 10^20 (colden) to 10^22 (sherpa)
    }
    close OUT;
    unlink $tmp1, $tmp2;

    1;
}

##****************************************************************************
sub get_fit_bkg_model_cmd {
##****************************************************************************
    my $self = shift;
    my $hdr = fits_read_hdr($self->file('arf'), 'SPECRESP');
    my $detnam = $hdr->{DETNAM};
    unless (defined $detnam) {
	message("ERROR - cannot find DETNAM parameter in header of ".$self->file('arf')."\n");
	return;
    }
    my ($det_num) = ($detnam =~ /ACIS-(\d)/);
    unless (defined $det_num) {
	message("ERROR - DETNAM '$detnam' does not match expected format\n");
	return;
    }
    my $acis_s = ($det_num == 4 or $det_num == 7);
    my $file = $self->{bkg_mdl_prefix} . ($acis_s ? 'acis-s.in' : 'acis-i.in');
    unless (-e $file) {
	message("ERROR - Cannot find background model file $file\n");
	return;
    }
    return "use $file";
}

##****************************************************************************
sub sherpa_fit {
##****************************************************************************
    my $self = shift;
    my $fit = 'die "Unsuccessful fit\n" unless $self->fit_ciao';
    chdir dirname($self->file('src'));

    # Convert the convenient model_format statement into a more usable hash
    $self->parse_model_format();

    # Customize each of the models to insert appropriate redshift, Gal NH etc
    map { $_ = $self->customize_string($_) } (values %{$self->{model}});

    $self->{fit_rules} = $self->customize_string($self->{fit_rules});
    $self->{fit_rules} =~ s/COUNTS/\$self->{counts}/g;
    $self->{fit_rules} =~ s/FIT/$fit/g;

    eval $self->{fit_rules};
    if ($@) {
	message("ERROR - $@");
	message($@);
	return;
    }

    1;
}

##****************************************************************************
sub fit_ciao {
##****************************************************************************
    my $self = shift;
    my $mdl_name = shift;
    my $unbinned = shift;
    my $fixed_mdl_name = latex_verbatim($mdl_name);
    my $cmd_file = "$mdl_name.in";
    my $out_file = "$mdl_name.out";

    local $_;

    # Set up sherpa vars that depend on whether data are grouped or not
    my $pi_file = $unbinned ? $self->file('pi') : $self->file('pi_bin');
    my $statistic = $unbinned ? $self->{unbinned_stat} : $self->{binned_stat};
    my $subtract = $unbinned ? '' : 'subtract';
    my $method = $unbinned ? $self->{unbinned_method} : $self->{binned_method};
    my $fit_background = $unbinned ? ($self->get_fit_bkg_model_cmd() or return) : '';

    # Assemble dependencies
    my @target = ("$mdl_name.mdl", "$mdl_name.in", "$mdl_name.ps");
    my @depend = map { $self->file($_) } qw(rmf bg_pi arf);
    push @depend, $pi_file;
    my @test_dep = (-target => \@target, -depend => \@depend );

    return 1 unless ($self->{fit} or $self->{force} or test_dep(@test_dep));
    unless ($self->{model}{$mdl_name}) {
	message("ERROR - Unknown model name '$mdl_name' specified\n");
	return;
    }
    map { unlink } glob("$mdl_name.*"); # Wipe out any existing sherpa fit files

    message("Fitting model $mdl_name\n");

    # Get the galactic NH if needed
    $self->set_gal_nh() unless defined $self->{gal_nh};

    open CMD, "> $cmd_file" or croak "ERROR - could not open $cmd_file for sherpa commands\n";
    print CMD <<CMDS_1
paramprompt off
evalfile("sherpa_plotfns.sl")
data $pi_file
$subtract
statistic $statistic
method $method
CMDS_1
  ;

    my $cmds = $self->customize_string($self->{sherpa_cmds});
    $cmds =~ s/_YAXX_MODEL_NAME_/"$fixed_mdl_name"/g;
    $cmds =~ s/_YAXX_FIT_BACKGROUND_IF_UNBINNED_/$fit_background/g;
    $cmds =~ s/_YAXX_COMMON_MODEL_DEFS_/$self->{model}{COMMON_MODEL_DEFS} || ''/ge;
    $cmds =~ s/_YAXX_DEFINE_SOURCE_MODEL_/$self->{model}{$mdl_name}/g;
    print CMD "$cmds\n";
    
    print CMD <<CMDS_3
print postfile $mdl_name.ps
write mdl "$mdl_name.mdl"
goodness
CMDS_3
  ;

    print CMD "projection\n" if $self->{projection};
    print CMD "uncertainty\n" if $self->{uncertainty};
    print CMD "eflux\n";
    print CMD "rs1_eflux=get_eflux(,,\"rs\")\n";
    print CMD "print(\"rs1 eflux: \"+string(rs1_eflux.value)+\" \"+string(rs1_eflux.units))\n";
    if ($mdl_name eq "bbrs2" || $mdl_name eq "bbrs2a") {
      print CMD "rs2_eflux=get_eflux(,,\"rs2\")\n";
      print CMD "print(\"rs2 eflux: \"+string(rs2_eflux.value)+\" \"+string(rs2_eflux.units))\n";
    } # if ($mdl_name eq "bbrs2") {
    close CMD;

    my $sherpa_out;
    return unless run_tool("sherpa --batch $cmd_file", { out => \$sherpa_out, timeout => 1000, loud => 1 });

    my %proj_result = parse_limits_table($sherpa_out, 'sherpa.proj') if $self->{projection};
    my %unc_result = parse_limits_table($sherpa_out, 'sherpa.unc') if $self->{uncertainty};
    return unless %proj_result or %unc_result;

    # Add projection/uncertainty results into mdl file if method was done and results obtained
    update_mdl_file($mdl_name, \%proj_result, 'proj') if %proj_result;
    update_mdl_file($mdl_name, \%unc_result, 'unc') if %unc_result;

    # Put the results of running 'goodness' into FITS header keywords for MDL file
    my %goodness_result = $unbinned ? ( f_method => $method,
					f_dof    => 1,
					f_chi    => 1,
					f_prob   => 1,
					f_redchi => 1) : parse_goodness($sherpa_out);

    my %source_info = (%goodness_result,
		       map {$_ => $self->format_var($_)} qw(ra dec object counts redshift class exposure)
		      );

    my %eflux_result = parse_eflux($sherpa_out);
    %source_head_info = (%eflux_result,%source_info,
		       map {$_ => $self->format_var($_)} qw(ra dec object counts redshift class exposure)
		       #map {$_ => $self->format_var($_)} qw(ra dec object counts redshift class exposure)
		      );

    # Write all the keyword = value pairs into a temp ASCII file for dmhedit
    my $tmp = POSIX::tmpnam();
    my @set_key;
    foreach (qw(ra dec object counts redshift class exposure 
                f_method f_dof f_chi f_prob f_redchi 
                eflux eflux_rs1 eflux_rs2)) {
	my $val = $source_head_info{$_} || 0;
	(undef, my $unused) = strtod($val);
	$val = "'$val'" if ($unused);
	push @set_key, "$_ = $val\n";
    }
    write_file($tmp, "#add\n", @set_key);

    # Add new keywords to file
    run_tool("dmhedit",
	     infile   => "$mdl_name.mdl[MDL_Models]",
	     filelist => $tmp,
	     { loud => 0 },
	    );
    unlink $tmp;

    if (test_dep(@test_dep)) {
	message("ERROR - fit failed to produce all files\n");
	return;
    }

    1;
}

##****************************************************************************
sub update_mdl_file {
#
# Put upper and lower limit values (from projection/uncertainty) in MDL file
# as new columns
##****************************************************************************
    # MDL file name, Results of projection/uncertainty, and type ('proj' or 'unc')
    my ($mdl_name, $proj, $type) = @_; 
    my ($model_name, $model, $comp_name, $comp);
    my @parname;
    my %upper;
    my %lower;
    local $_;

# Straight from CIAO::Sherpa::Parse
    while (($model_name, $model) = each %{$proj}) {
	while (($comp_name, $comp) = each %{$model}) {
	    $upper{"$model_name.$comp_name"} = $comp->{upper};
	    $lower{"$model_name.$comp_name"} = $comp->{lower};
	}
    }

    # Read in existing MDL file for this $mdl_name, then get parameter
    # upper and lower limits where they exist.  Put in a hash and call fits_write_bintbl

    my %mdl = fits_read_bintbl("$mdl_name.mdl[MDL_Models]", 'parname');
    my @lower_lims = map { $lower{$_} || 0.0 } @{$mdl{parname}};
    my @upper_lims = map { $upper{$_} || 0.0 } @{$mdl{parname}};
    my %out = ("${type}_lower" => \@lower_lims,
	       "${type}_upper" => \@upper_lims);
    fits_write_bintbl("$mdl_name.$type", %out);

    # Paste the new columns into the MDL_Models extension of the MDL file, then rebuild
    # the entire file (with both blocks) using dmcopy and dmappend

    $tmp = POSIX::tmpnam();
    $tmp2 = POSIX::tmpnam();
    run_tool("dmpaste",
	     infile => "$mdl_name.mdl[MDL_Models]",
	     pastefile => "$mdl_name.$type",
	     outfile => $tmp,
	    {loud => 0});
    run_tool("dmcopy", infile => "$mdl_name.mdl[MDL_Data]", outfile => $tmp2, {loud => 0});
    run_tool("dmappend", infile => $tmp, outfile => $tmp2, {loud => 0});
    move $tmp2, "$mdl_name.mdl";
    unlink $tmp;

    message("Successfully updated $mdl_name.mdl file\n");
}

##****************************************************************************
sub parse_goodness {
##****************************************************************************
#Goodness: computed with Chi-Squared Gehrels
#
#DataSet 1: 75 data points -- 73 degrees of freedom.
# Statistic value       = 76.9533
# Probability [Q-value] = 0.353304
# Reduced statistic     = 1.05415
    my ($PS) = shift;
    my $RE_Float = qr/[+-]?(?:\d+[.]?\d*|[.]\d+)(?:[dDeE][+-]?\d+)?/;
    my %result;

    $PS =~ /Goodness: computed with (.+)/igc
      or do { message( "ERROR - Couldn't find Goodness results"); return};
    $result{f_method} = $1;

    $PS =~ /DataSet.+--\s+(\d+) degrees of freedom/igc
      or do { message( "ERROR - Couldn't find Goodness results"); return};
    $result{f_dof} = $1;

    $PS =~ /Statistic value\s*=\s*($RE_Float)/igc
      or do { message( "ERROR - Couldn't find Goodness results"); return};
    $result{f_chi} = $1;

    $PS =~ /Probability \[Q-value\]\s*=\s*($RE_Float)/igc
      or do { message( "ERROR - Couldn't find Goodness results"); return};
    $result{f_prob} = $1;

    $PS =~ /Reduced statistic\s*=\s*($RE_Float)/igc
      or do { message( "ERROR - Couldn't find Goodness results"); return};
    $result{f_redchi} = $1;

    return %result;
}

##****************************************************************************
sub parse_limits_table {
##****************************************************************************
  my ( $PS )  = shift;
  my $command = shift;
  my $RE_Float = qr/[+-]?(?:\d+[.]?\d*|[.]\d+)(?:[dDeE][+-]?\d+)?/;
  my $Null_Lim = qr/--+/;

  # next, we look for the results.
  $PS =~ /Computed for\s+$command\.(\S+)[ \t]*=[ \t]*(.*)\n/igc    # CIAO 3.0.1
    or do { message( "ERROR - Couldn't find $command results\n");
	    return};

  my $method_var = $1;
  my $method_val = $2;

  my %result;

  # next three lines are like this:
  #      --------------------------------------------------------
  #      Parameter Name      Best-Fit Lower Bound     Upper Bound
  #      --------------------------------------------------------

  $PS =~ /\G\s+-+\n/gc && 
    $PS =~ /\G\s+Parameter Name.*\n/gc &&
      $PS =~ /\G\s+-+\n/gc
	or do {message("ERROR - out of sync for $command command; expecting Results header");
	       return};

  while ( $PS =~ /\G
                  [ \t]*(\S+)\.(\S+)
                  [ \t]+($RE_Float)
                  [ \t]+($RE_Float|$Null_Lim)
                  [ \t]+($RE_Float|$Null_Lim)
                  .*\n
                 /xgc )
  {
    # can't assign it in the regexp match above, else \G doesn't get set right
    my ( $model, $param, $best, $lower, $upper ) = ( $1, $2, $3, $4, $5 );
#    $upper = '+0.00' if ($upper =~ /$Null_Lim/);
#    $lower = '-0.00' if ($lower  =~ /$Null_Lim/);
    $upper = $NAN if ($upper =~ /$Null_Lim/);
    $lower = $NAN if ($lower  =~ /$Null_Lim/);

    $result{$model}{$param}{best}  = $best;
    $result{$model}{$param}{lower} = $lower;
    $result{$model}{$param}{upper} = $upper;
  }

  return %result;
}

##****************************************************************************
sub parse_eflux {
##****************************************************************************
#Flux for source dataset 1: 3.02823e-14 ergs/cm**2/s
#
    my ($PS) = shift;
    my %result;

    $PS =~ /dataset 1: (.+) ergs/igc
      or do { message( "ERROR - Couldn't find eflux results"); return};
    $result{eflux} = $1;
    $PS =~ /rs1 eflux: (.+) ergs/igc;
    $result{eflux_rs1} = $1 || 0;
    $PS =~ /rs2 eflux: (.+) ergs/igc;
    $result{eflux_rs2} = $1 || 0;

    return %result;
}

##****************************************************************************
sub make_report {
#
# Make report files that summarize source and fit results.  'Groups' of
# source models can be defined if there are too many to fit on one page
#
##****************************************************************************
    my $self = shift;
    local $_;
    my @source;
    my %latex;
    
    return 1 if ($self->{fakeid} or $self->{no_ds9}); # No report for fake datasets
    
    chdir dirname $self->file('report'); #  For latex we need to be in this directory
    my $report = $self->file('report');
    my $image = $self->file('ds9_image');

    my @groups = keys %{$self->{report}{group}};
    my @target = map { $self->file('report', {ext=>'.ps', group=>$_}) } @groups;
    my @test_dep = (-target => \@target, -depend => [glob("*.mdl"), $image]);
    return 1 unless test_dep(@test_dep);

    # Now prefer to use '-preclean validated' if this is wanted
    ## Remove the V&V file when new report is created  
    ##    unlink $self->file('validated') if (-e $self->file('validated'));

    # Clean up
    map { unlink } glob("$report*");

    # Create the common components for all latex report files

    # Customize the generic latex commands in config file to be specific
    # to this source
    while (my ($key, $val) = each %{$self->{report}{latex}}) {
	$latex{$key} = $self->customize_string($val);
    }

    # Go through each group and make report.  The group '' defaults to include all source models
    foreach my $group (@groups) {
	# Make fit tables and fit images, which are specific to group
	($latex{fit_table}, $latex{fit_images}) = $self->report_fit_table_and_images($group);

	# Make the actual report
	$report = $self->file('report', {group => $group});
	open TEX, "> $report.tex" or do {
	    message("ERROR - Could not open latex file '$report.tex' for writing $@\n");
	    return;
	};

	my $layout = $self->{report}{group}{$group}{layout}; # This may be a scalar or array ref

	print TEX $latex{header};
	map { print TEX $latex{$_} } (ref($layout) eq "ARRAY" ? @{$layout} : $layout);
	print TEX $latex{closer};
	close TEX;

	run_tool("latex -interaction=batchmode $report", {timeout => 120});
	unless (-e "$report.dvi") {
	    message("ERROR - latex failed to run correctly\n");
	    return;
	}

	run_tool("dvips $report -o", {timeout => 120});
	unless (-e "$report.ps") {
	    message("ERROR - dvips failed to run correctly\n");
	    return;
	}

	map {unlink "$report.$_"} qw(aux dvi log);
    }

    1;
}

##****************************************************************************
sub customize_string {
#
#  Substitute format($self->{stuff}) for _YAXX_{ stuff } everywhere in string
##****************************************************************************
    my $self = shift;
    my $str  = shift;

    # Keep pounding on string, finding occurences of _YAXX_{ stuff }
    # and substituting format($self->{stuff}).  (String is small, so
    # don't worry about inefficiency)

    while ($str =~ /_YAXX_([A-Z_]*) \{ (\s* \w+ \s*) \}/x) {
	my $substr = $MATCH;
	my $val;
	switch ($1) {
	    case 'FILE_' { $val = $self->file($2) }
	    case 'TEX_'  { $val = latex_verbatim($self->format_var($2)) }
            else         { $val = $self->format_var($2) }
	}
	$str =~ s/$substr/$val/g; # replace multiple occurences if possible
    }

    return $str;
}

#********************************************************************************
sub format_var {
#
#  Format a variable for summary in accordance with specs in {report}{summary_format}
#********************************************************************************
    my $self = shift;
    my $var  = shift;
    my $val;
    
    # Get rid of any leading/trailing spaces
    $var =~ s/(\A\s+|\s+\Z)//g;

    # Use predefined format or just '%s'
    my $format = $self->{report}{summary_format}{$var} || '%s';

    # Format defined variable or else return '---'
    return defined $self->{$var} ? sprintf($format, $self->{$var}) : '---';
}

#********************************************************************************
sub parse_model_format {
#
#  Parse something like    pow1.ampl     fmt=%.2f unit=$10^{-5}$ mult=1e5 into hash
#********************************************************************************
    my $self = shift;
    
    return unless (my $mf = $self->{report}{model_format});

    while (my ($key, $val) = each %{$mf}) {
	next if ref($val);	# $val may already be a hash ref
	my %fmt = map { $1 => $2 if /(\S+)=(\S+)/ } split(' ', $val);
	$mf->{$key} = { %fmt };
    }
}


#********************************************************************************
sub report_fit_table_and_images {
#
#  Go through Sherpa .mdl files, extract all relevant fit parameters, and
#  create commands for latex fit table summary
#
#  Assumes Cwd = src directory
#********************************************************************************
    my $self = shift;
    my $group = shift;
    local $_;

    my %table;
    my $row = 0;
    my ($value, $upper, $lower);
    my $CHI_SQ = "\$\\chi^{2}\$.(DOF)";

    # NB "source" is used in the sherpa dialect to mean a source model
    # (e.g. pl_abs) used to fit data.  Not to be confused with a source of photons

    # Grab each source mdl file which defines model and best fit parameters
    map { s/\.mdl// } (@source = glob("*.mdl"));

    # If non-trivial group is specified, then filter source model list accordingly
    if ($group ne 'ALL_MODELS') {
	my $models = $self->{report}{group}{$group}{models}; # May be a scalar or array ref
	my %group_models = map { $_ => 1 } (ref($models) eq "ARRAY" ? @{$models} : $models);
	@source = grep { $group_models{$_} } @source;
    }

    foreach my $source (@source) {

	my %mdl = fits_read_bintbl("$source.mdl\[MDL_Models\]");
	my $mdl_header = fits_read_hdr("$source.mdl", "MDL_Models");
	for my $i (0..$#{$mdl{model}}) {
	    my $parname = $mdl{parname}->[$i];

	    my $format = $self->get_model_format($parname);
	    if ($parname and $parname =~ /\S/ and not $format->{ignore}) {
		$value = $mdl{parvalue}->at($i);
		$upper = exists $mdl{proj_upper} ? $mdl{proj_upper}->at($i)
		  : (exists $mdl{unc_upper} ? $mdl{unc_upper}->at($i) : 0);
		$lower = exists $mdl{proj_lower} ? $mdl{proj_lower}->at($i)
		  : (exists $mdl{unc_lower} ? $mdl{unc_lower}->at($i) : 0);
		unless ($table{cols}->{$parname}) { # Seen this parname already?
		    $table{cols}->{$parname} = 1;
		    push @{$table{col_list}}, $parname;	# Keep track of cols in order
		}
		($lower, $upper) = fix_uncertainties($self, 'report', $parname, $value, $lower, $upper);
		$table{rows}->[$row]->{$parname} = format_entry($format, $value,
								$lower, $upper);
	    }
	    if ($mdl{statname}->[$i] =~ /\S/) {
		$table{cols}->{$CHI_SQ} = 1;
		$table{rows}->[$row]->{$CHI_SQ} = format_entry({fmt=>"%.1f"}, $mdl{statval}->at($i)) 
		  . "($mdl_header->{F_DOF})"
	    }
	}
	$row++;			# Next row in table 
    }
    push @{$table{col_list}}, $CHI_SQ;
	
    # Now actually assemble the latex commands to make the table
    my $t;
    $t .=  "\\centerline{\n";
    $t .=  "\\begin{tabular}{l";
    map {$t .=  "c"} (1..@{$table{col_list}});
    $t .=  "}\n";
    $t .=  "\\hline\n";
    $t .=  " & " . join(" & ", map {/(\S+)\.(\S*)/; $1} @{$table{col_list}}) . "\\\\ \n";
    $t .=  " & " . join(" & ", map {/(\S+)\.(\S*)/; $2} @{$table{col_list}}) . "\\\\ \n";
    $t .=  " & " . join(" & ", map {$self->{report}{model_format}->{lc($_)}->{unit} || ''} @{$table{col_list}}) . "\\\\ \n";
    $t .=  "\\hline\n";
    for $i (0..$row-1) {
	$t .=  latex_verbatim($source[$i]) . " & ";
	$t .=  join(" & ", map { $table{rows}->[$i]->{$_} || '' } @{$table{col_list}});
	$t .=  "\\\\ \n";
    }
    $t .=  "\\hline\n";
    $t .=  "\\end{tabular}} \n";
    $t .=  "\\ \\\\\n\n";

    my $s;			# latex for fit images
    my $fig_size = (@source >= 3) ? 2.25 : 2.25;
    my $count = 1;
    for $source (@source) {
	$s .= "\\resizebox{${fig_size}in}{!}{\\includegraphics{$source.ps}} \n";
	$s .= "\\vspace{0.1in} \\\\ \n" if ($count++ % 3 == 0);
    }

    return $t, $s;
}

#********************************************************************************
# Go to next instance if this is a fake dataset
# Check if it exists by looking for pi file.  (Always succeeds for fakeid==0,
# which is the 'real' dataset)
sub next_instance {
#********************************************************************************
    my $self = shift;

    # Go to next fake dataset, or to the real dataset (fakeid==0) if this is the
    # first request for the 'next instance'
    $self->{fakeid} = defined $self->{fakeid} ? $self->{fakeid}+1 : 0;

    # Return true (implying data for this fakeid are available) if
    # fakeid==0 is the real data, so it is always there.
    # If fakeid > 0, this is fake data, so check that it exists and
    # that processing of fake data is allowed
   return ($self->{fakeid} == 0
	    or ($self->{process_fake} && -d dirname($self->file('pi')))
	   );
}

##****************************************************************************
sub make_fakes {
# 
# Make new (derived) datasets
#
##****************************************************************************
    my $self = shift;
    my $n_fake = shift;
    my $fake;
    my %cols = (copy => [qw(pi)],
		make_local_copy => [qw(yaxx_info src bkg all_reg rmf arf
				       bg_pi bg_rmf bg_arf asphist ds9_image)]);
    local $_;

    croak "Error - need to set process_fake=1 in config file for fake data\n"
      unless ($self->{process_fake});

    # Go to base directory
    local $CWD = $self->{base_dir};

    # return if src or obs should be ignored
    return 1 if (-e $self->file('ignore_src') or -e $self->file('ignore_obs'));

    foreach $fakeid (1 .. $n_fake) {
	# Make a fake source corresponding to the real source 
	#  Make directories in fake source, and then copy pi rmf arf files 
	#  as well as correct MDL file

	$fake = new YaxxSource($self, {fakeid => $fakeid});

	message("Create fake files in " . dirname($fake->file('src')) . "\n");

	# (This should really be a true dependence test...)
	next if (-e $fake->file('pi', {ext => '.gz'}) or -e $fake->file('pi'));;	# Skip if already faked

	# Initialize data directories and data as for a normal source
	$fake->make_dirs();
	$fake->gunzip();
	$fake->clean($self->{preclean});
	$fake->get_data_files();

	# (SHOULD ALSO copy mdl files, but this needs globbing or special treatment)
	foreach my $op (keys %cols) {
	    foreach (@{$cols{$op}}) {
		my $fake_file = $fake->file($_);
		my $real_file = $self->file($_);

		if (-e $real_file) {
		    if (-e $fake_file) {
			message("make_fakes: Warning - $fake_file already exists, skipping\n");
			next;
		    }
		    &{$op}($real_file, $fake_file);
		}
	    }
	}

	# Now finally run the thing which generates fake data
	if ($fake->{fake_program}) {
	    local $CWD = $self->{CWD}; # Go to user directory from which yaxx was called
	    my $fake_program = $fake->customize_string($fake->{fake_program});
	    message("Running $fake_program\n");
	    system($fake_program);
	}

	# .. and make the grouped (binned) file
	$fake->set_pi_info();
	$fake->group_pi_file();

    } continue {
	$fake->gzip();
    }

    1;
}

#********************************************************************************
sub set_pi_info {
#********************************************************************************
    my $self = shift;

# Set the net counts variable, either from 'net_B' (XPIPE) or from PI file header
    return unless (-e $self->file('pi') and -e $self->file('bg_pi'));
    my $hdr = fits_read_hdr($self->file('pi'), 'spectrum');
    my $hdr_bkg = fits_read_hdr($self->file('bg_pi'), 'spectrum');
    $self->{counts} = $hdr->{TOTCTS} - $hdr_bkg->{TOTCTS} * $hdr->{BACKSCAL} / $hdr_bkg->{BACKSCAL};
    $self->{pi_net_cts} = $self->{counts};
    $self->{pi_tot_cts} = $hdr->{TOTCTS};
    $self->{exposure} = $hdr->{EXPOSURE};
}

#********************************************************************************
sub xpipe_info {
#********************************************************************************
    my $self = shift;
    return if (-e $self->file('ignore_src') or -e $self->file('ignore_obs'));

    $self->set_pi_info();

    print "Setting xpipe info for ", (map {" $self->{$_}"} qw(object obsid ccdid srcid)), "\n";

    return {map {$_ => $self->{$_}} @{$self->{xpipe_info_cols}}};
}

#********************************************************************************
sub summary {
#********************************************************************************
    my $self = shift;
    my $mdl_name = shift;
    local $_;

    my %table;
    my @cols;
    my %info;
    my @info_cols = qw(RA DEC OBJECT COUNTS REDSHIFT CLASS EXPOSURE
		       F_METHOD F_DOF F_CHI F_PROB F_REDCHI);
    my ($value, $upper, $lower);

    return if (-e $self->file('ignore_src') or -e $self->file('ignore_obs'));

    # Try to find mdl file, which might be gzipped.  Why can't I make glob do this?
    my ($file) = grep /\.mdl(\.gz)?\Z/, glob(dirname($self->file('src')) . "/${mdl_name}.mdl*");
    return unless ($file && -e $file);	# Return (without issuing a warning) if no file found.
				# This likely means this model is not fit for this source

    my %mdl = fits_read_bintbl("$file\[MDL_Models\]");
    my $mdl_header = fits_read_hdr("$file", "MDL_Models");

    @cols = qw(obsid ccdid srcid);
    push @cols, 'fakeid' if $self->{process_fake};
    map { $table{$_} = $self->{$_} } @cols;

    # Insert supplemental information from header if possible
    message("WARNING - No supplemental summary info in $file\n") unless (defined $mdl_header->{RA});
    foreach (@info_cols) {
	if (defined $mdl_header->{$_}) {
	    $table{lc $_} = $mdl_header->{$_};
	    push @cols, lc $_;
	}
    }
    
    for $i (0..$#{$mdl{model}}) {
	my $parname = $mdl{parname}->[$i];
	my $format = $self->get_model_format($parname);
	if ($parname and $parname =~ /\S/) {
	    $value = $mdl{parvalue}->at($i);
	    $upper = exists $mdl{proj_upper} ? $mdl{proj_upper}->at($i)
	      : (exists $mdl{unc_upper} ? $mdl{unc_upper}->at($i) : undef);
	    $lower = exists $mdl{proj_lower} ? $mdl{proj_lower}->at($i)
	      : (exists $mdl{unc_lower} ? $mdl{unc_lower}->at($i) : undef);
	    push @cols, $parname;

	    $table{$parname} = format_entry($format, $value);
	    ($lower, $upper) = fix_uncertainties($self, 'summary', $parname, $value, $lower, $upper);
	    $table{"$parname.up"} = format_entry($format, $upper) if (defined $upper);
	    $table{"$parname.low"} = format_entry($format, $lower) if (defined $lower);
	}
    }
    return {cols=>[@cols], data=>{%table}};
}

#********************************************************************************
sub get_model_format {
# 
# Find the longest model format name that matches the end of param name
#********************************************************************************
    my $self = shift;
    my $parname = shift;
    local $_;

    return unless ($parname =~ /\S/);
    my $len = -1;
    my $fmt;
    my $mf = $self->{report}{model_format};

    foreach (keys %{$mf}) {
	if ($parname =~ /$_\Z/i and length > $len) {
	    $fmt = $mf->{$_};
	    $len = length;
	}
    }

    return $fmt;
}

#********************************************************************************
sub fix_uncertainties {
#********************************************************************************
    my $self = shift;
    my ($type, $parname, $value, $lower, $upper) = @_;
    my %in = (lower => $lower,
	       upper => $upper);
    my %out = %in;
    my $inf = '\infty';
    local $_;

    return ($lower, $upper) unless (my $rules = $self->{uncertainty_rules});

  RULE: foreach (split "\n", $rules) {
	chomp;
	s/INF/$inf/g;
	s/VALUE/$value/g;

	if (($lim, $summary, $report) =/\A \s* $parname.(lower|upper) \s+ (\S+) \s+ (\S+) \s* \Z/xi) {
	    next RULE unless defined $in{$lim};
	    if ($in{$lim} != $in{$lim}) { # only possible if value = NaN, meaning uncert. pegged
		$out{$lim} = ($type eq 'summary') ? $summary : $report;
	    }
	}
    }

    return ($out{lower}, $out{upper});
}

#********************************************************************************
sub latex_verbatim {
#
# Fix any characters which have special meaning to latex, e.g. _ => \_
#********************************************************************************
    local $_;
    $_ = shift;
    my @fix = ( qr{\\} => '\$\\backslash\$',
		qr{%} => '\\%',
		qr{\$} => '\\\$',
		qr{<} => '\$<\$',
		qr{>} => '\$>\$',
		qr/}/ => '\$\\}\$',
		qr/{/ => '\$\\{\$',
		qr/&/ => '\\&',
		qr/#/ => '\\#',
		qr/\^/ => '\\^',
		qr/_/ => '\\_',
		qr/~/ => '\\~{}',
		);

    # Go through the fixes (in order!) and apply globally
    my ($plain, $tex);
    while ($plain = shift @fix and $tex = shift @fix) {
	s/$plain/$tex/g;
    }

    return $_;
}

#********************************************************************************
sub format_entry {
#********************************************************************************
    my $RE_Float = qr/[+-]?(?:\d+[.]?\d*|[.]\d+)(?:[dDeE][+-]?\d+)?/;
    my ($format, $value, $lower, $upper) = @_;
    my $mult = $format->{mult} || 1;
    my $fmt = $format->{fmt} || "%s";
    my $out = sprintf $fmt, $value * $mult;

    # Add the lower and upper limits
    $out .= '$' if ($lower or $upper);
    if ($lower) {
	$out .= ($lower =~ /$RE_Float/) ? sprintf("_{-$fmt}", abs($lower*$mult))
	  : "_{$lower}";
    }
    if ($upper) {
	$out .= ($upper =~ /$RE_Float/) ? sprintf("^{+$fmt}", abs($upper*$mult))
	  : "_{$upper}";
    }
    $out .= '$' if ($lower or $upper);

    return $out;
}

#********************************************************************************
sub open_log {
#
# Open a log file (using 'message') for processing related to this source
#********************************************************************************
    my $self = shift;
    my $log = $self->file('log');
    local $_;

    if (-e $log) {
	my $max = 1;
	map { $max = $1+1 if (/${log}\.(\d+)/ and $1 >= $max) } glob("${log}*");
	move($log, "$log.$max");
    }
    message('', (init  => 1,
		 log_file => $log));
    1;
}

#********************************************************************************
sub close_log {
#********************************************************************************
    my $self = shift;
    message('', (close => 1, 
		 log_file => $self->file('log')));
}


#********************************************************************************
sub fast_check {
#
# Do a quick and dirty check that file has been processed to completion
# Look for existence of any mdl files.  This is not generally reliable,
# but is probably OK in many circumstances.
# Return 1 if sources has NOT been processed already
#********************************************************************************
    my $self = shift;

    return 1 unless $self->{fast_check}; # Don't do this unless specifically enabled
    
    my $dir = dirname $self->file('src');
    my @mdl_files = grep /\.mdl(\.gz)?\Z/, glob("$dir/*");

    return (@mdl_files == 0);
}

1;
