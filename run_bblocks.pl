#! /usr/bin/perl
# run bayesian blocks routines on a list of sources
# * needs sherpa (slang) *
# 

if ($#ARGV < 1) {
  die "Usage:\n  $0 <infile> <obsid> [ncp_prior]\n";
}
$prior = 3;  #default 95%
$label="";   #don't label if using default prior - for back compatability
if ($#ARGV == 2) {
  $prior=$ARGV[2];
  $label="_".$ARGV[2];
}
# check obsid, directory structure is rigid
chomp $ARGV[1];
$data_dir=$ARGV[1];
@chars=split //,$data_dir;
while ($chars[0] eq "0") {
  $data_dir = join '', @chars[1..$#chars];
  @chars=split //,$data_dir;
} # while ($chars[0] eq "0") {
$obs_dir=$data_dir;
@chars=split //,$obs_dir;
while ($#chars < 4) {
  $obs_dir= "0".$obs_dir;
  @chars=split //,$obs_dir;
} # while ($count < 5) {

$data_root="/data/ANCHORS/YAXX/$obs_dir/Data/obs$data_dir";

$logfile="bblocks.log";
$scrfile="bblocks_script.sl";
$evt_file="bblocks_src_evt.fits";
$bkg_file="src_bkg.fits";

open(IN,"<$ARGV[0]") || die "Input file $ARGV[0] not found.\n";
$inline=<IN>; # skip first 2 header lines
$inline=<IN>; # skip first 2 header lines
while ($inline=<IN>) {
  chomp $inline;
  @line=split(/\s+/,$inline);
  @src_str=split("_",$line[0]);
  $src=$src_str[1];
  $src_root=$data_root."/src".$src;

  $command="dmcopy '".$src_root."/acis_evt2.fits[sky=region(".$src_root."/src.reg)]' ".$evt_file." clobber=yes";
  #print "$command\n"; #dbug
  `$command`;
  $command="dmcopy '".$src_root."/acis_evt2.fits[sky=region(".$src_root."/bkg.reg)]' ".$bkg_file." clobber=yes";
  `$command`;
  #print "$command\n"; #dbug
  #print "Working SRC $src\n"; # debug
  open (SCR,">$scrfile");
  print SCR "variable file=\"$evt_file\";\n";
  print SCR "variable ncp_prior = 3;\n";
  print SCR "variable plot_step = 1600.;\n";
  print SCR "variable ctype = 1;\n";
  print SCR "variable bsize = 1.14104*3.;\n";
  print SCR "variable clump = 0.5;\n";
  print SCR "variable plotit = 1;\n";
  print SCR "variable talt = 0;\n";
  print SCR "variable writeit = 0;\n";
  print SCR "() = evalfile(\"sitar.sl\");\n";
  print SCR "() = evalfile(\"bblocks_examp.sl\");\n";
  print SCR "variable event_times, tstart, tstop, frame, dtcor, object;\n";
  print SCR "(event_times, tstart, tstop, frame, dtcor, object) = sitar_examp_read(file);\n";
  print SCR "object=\"src$src\";\n";
  print SCR "variable tstart_file = tstart, tstop_file = tstop;\n";

  print SCR "if(talt)   { tstart = min(event_times);      tstop = max(event_times);   }\n";

  print SCR "if(ctype == 3 and bsize > 0.)   {      frame = bsize;   }\n";

  print SCR "variable cell;\n";
  print SCR "cell = sitar_make_data_cells( event_times,ctype,clump,frame,tstart,tstop );\n";

  print SCR "cell.dtcor = cell.dtcor * dtcor;\n";

  print SCR "variable results = sitar_global_optimum( cell, ncp_prior, ctype );\n";

  print SCR "plot_step=int((tstop-tstart)*5./length(event_times));\n";
  print SCR "variable ev;\n";
  print SCR "ev = sitar_examp_bin( event_times, tstart, tstop, dtcor, plot_step);\n";

  # we'll make our own plots
  #  unless, we can get chips or pgplot to do pngs,
  #   but still need to do some filtering of blocks first, see
  #   collect_sources.pl and bblock_plot.pro
  print SCR "sitar_examp_plot( results, ev, object, file, plot_step, ncp_prior, tstart_file, tstop_file, plotit);\n";
  print SCR "sitar_examp_write( results, object, file, plot_step, ncp_prior );\n";
  close SCR;
  unlink $logfile;
  $command="sherpa --batch $scrfile > $logfile";
  #print "$command\n";
  `$command`;

  $command="mv bblocks.dat ".$src_root."/bblocks".$label.".dat";
  `$command`;
  $command="mv bblocks_plot.ps ".$src_root."/bblocks_plot".$label.".ps";
  `$command`;
  $command="mv bblocks_plot.fits ".$src_root."/bblocks_plot".$label.".fits";
  `$command`;
  $command="mv ".$evt_file." ".$src_root."/src".$src."_evt.fits";
  `$command`;
  $command="mv ".$bkg_file." ".$src_root."/src".$src."_bkg_evt.fits";
  `$command`;


} #while ($inline=<IN>) {
close IN;
