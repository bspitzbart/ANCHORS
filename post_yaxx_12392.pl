#!/usr/bin/perl

$nargs=2;
$proc="-f";
if ($ARGV[0] eq "-p" || $ARGV[0] eq "-f" || $ARGV[0] eq "-r" || $ARGV[0] eq "-s" || $ARGV[0] eq "-t") {
  $proc=$ARGV[0];
  $nargs=3;
  $ARGV[0]=$ARGV[1];
  $ARGV[1]=$ARGV[2];
  $ARGV[2]=$ARGV[3];
}
if ($#ARGV != $nargs) {
  print "\n  Usage: \n";
  print "    $0 [-frpst] <sample.rdb> <obsid> <expmap>\n\n";
  print "        -f: optional flag to force all processing (default)\n\n";
  print "    Other flags are used to repost an obsid.  \n";
  print "    No data analysis (bblocks, quantiles, etc.) is done, \n";
  print "    just data compilation steps.  To be used after a yaxx rerun, \n";
  print "    or after executing some other step manually.\n\n";
  print "        -r: repost all sources and top level files; \n";
  print "            <sample.rdb> lists all sources for <obsid>\n";
  print "            Also redraws spectral and bblocks plot.\n";
  print "        -p: only repost all sources and top level files; \n";
  print "            <sample.rdb> lists all sources for <obsid>\n";
  print "            Does not redraw plots.n";
  
  print "\n    The -s and -t flags are usually run in sequence \n";
  print "      after rerunning SOME sources in yaxx with no change \n";
  print "      in regions.\n\n";
  print "        -s: repost some sources; <sample.rdb> is a sublist of \n";
  print "            sources for <obsid>\n";
  print "        -t: repost top level files; <sample.rdb> lists all sources \n";
  print "            for <obsid>\n";
  #print " updates, without checking dependancies.\n";
  #print "         NOT YET IMPLEMENTED - NO DEPENDANCIES ARE EVER CHECKED!\n";
  
  die ("\n");
}

$prog_dir="/data/ANCHORS/YAXX/bin_linux";

if ($proc eq "-f") {
  # run idl programs plot_bblocks.pro and plot_spectra.pro  ...
  open(IDL,">run_idl_plots.pro");
  print IDL "bblocks_plot,\'$ARGV[0]\', \'$ARGV[1]\'\n";
  print IDL "spectra_plot,\'$ARGV[0]\', \'$ARGV[1]\'\n";
  print IDL "GLvary_plot,\'$ARGV[0]\', \'$ARGV[1]\'\n";
  print IDL "exit\n";
  close IDL;
  `idl run_idl_plots`;

}  # if ($proc eq "-f") {


if ($proc eq "-p" || $proc eq "-f" || $proc eq "-r" || $proc eq "-s") {
  print "collect_target_table.pl $ARGV[0] $ARGV[1]\n";
  `$prog_dir/collect_target_table.pl $ARGV[0] $ARGV[1] $ARGV[2]`;

  print "assemble_report.pl $ARGV[0] $ARGV[1]\n";
  `$prog_dir/assemble_report.pl $ARGV[0] $ARGV[1]`;

  print "merge2web.pl $ARGV[0] $ARGV[1]\n";
  `$prog_dir/merge2web.pl $ARGV[0] $ARGV[1]`;
}  # if ($proc eq "-f" || $proc eq "-r" || $proc eq "-s") {

if ($proc eq "-p" || $proc eq "-f" || $proc eq "-r" || $proc eq "-t") {
  print "assemble_csv.pl $ARGV[0] $ARGV[1]\n";
  `$prog_dir/assemble_csv.pl $ARGV[0] $ARGV[1]`;

  print "assemble_obs.pl $ARGV[0] $ARGV[1]\n";
  `$prog_dir/assemble_obs.pl $ARGV[0] $ARGV[1]`;
}  # if ($proc eq "-f" || $proc eq "-r" || $proc eq "-t") {

#end
