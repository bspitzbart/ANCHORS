#!/usr/bin/perl
# set up web area for given obsid
# $ARGV[0] is name of file which contains list of source numbers and
# RA,Dec to process
#  read (sample.rdb) (same as yaxx input file)

use coords;

if ($#ARGV != 1) {
  die "Usage:\n  $0 <infile> <obsid>\n";
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
$html_root="/proj/web-cxc-dmz/htdocs/ANCHORS/$obs_dir";
$outxml="/data/ANCHORS/YAXX/$obs_dir/$data_dir.xml";

open(IN,"<$ARGV[0]") || die "Input file $ARGV[0] not found.\n";
#if (-d "$html_root") { die "$html_root already exists.\n";}
if (! -d "$html_root") { 
  mkdir("$html_root",0755) || die "Cannot create $html_root\n";}
if (! -d "$html_root/Proc") { 
  mkdir("$html_root/Proc",0755) || die "Cannot create $html_root/Proc\n";}
if (! -d "$html_root/download") { 
  mkdir("$html_root/download",0755) || die "Cannot create $html_root/download\n"};
open(MAP,">$html_root/map_name"); # map src# to new name
`rsync $outxml $html_root/obs.xml`;
`rsync $data_root/../../LOG/* $html_root/Proc`;
`rsync $data_root/*log $html_root/Proc`;
`rsync $data_root/../../*csv $html_root/download`;
`rsync $data_root/../../*pdf $html_root/download`;
`rsync $data_root/../../book* $html_root/download`;

$inline=<IN>; # skip first 2 header lines
$inline=<IN>; # skip first 2 header lines
while ($inline=<IN>) {
  chomp $inline;
  @line=split(/\s+/,$inline);
  @src_str=split("_",$line[0]);
  $src=$src_str[1];
  $src_root="$data_root/src$src";
 
  # make new name
  $ra=$line[2];
  $dec=$line[3];
  ($ra_str,$dec_str)=&dec2seg($ra,$dec);
  @strra=split(":",$ra_str);
  $strra[2]=sprintf("%4.1f",$strra[2]);
  $strra[2]=~ s/^\s+//;
  $strra[2]=substr("0".$strra[2],-4,4);
  @strdec=split(":",$dec_str);
  $strdec[2]=sprintf("%2d",$strdec[2]);
  $strdec[2]=~ s/^\s+//;
  $strdec[2]=substr("0".$strdec[2],-2,2);
  if ($strdec[0] < 0 && $strdec[0] > -10) { $strdec[0]="-0".abs($strdec[0]); }
  elsif ($strdec[0] >= 0) { $strdec[0]="+".$strdec[0]; }
  print "$ra_str $dec_str\n";
  print "@strra @strdec\n";

  $src_name=join("",@strra).join("",@strdec);
  $src_html="$html_root/$src_name";
  print MAP "$src\t$src_name\n";

  mkdir("$src_html",0755) || print "Could not create $src_html\n";
  mkdir("$src_html/Logs",0755) || print "Could not create $src_html/Logs\n";

  `rsync $src_root/src$src.xml $src_html/src.xml`;
  `rsync $src_root/src$src\_2mass.xml $src_html/2mass.xml`;
  `rsync $src_root/chandra.jpg $src_html`;
  `rsync $src_root/2mass.jpg $src_html`;
  `rsync $src_root/bblocks_plot.gif $src_html`;
  `rsync $src_root/src$src\_evt.fits $src_html/src_evt.fits`;
  `rsync $src_root/src$src\_bkg_evt.fits $src_html/bkg_evt.fits`;
  `rsync $src_root/src.reg $src_html`;
  `rsync $src_root/bkg.reg $src_html`;
  `rsync $src_root/src_evt.fits $src_html`;
  `rsync $src_root/bkg_evt.fits $src_html`;
  `rsync $src_root/log* $src_html/Logs`;
  `rsync $src_root/yaxx.dmp $src_html/Logs`;

  #@trap=`ps2gif $src_root/bblocks_plot.ps $src_html/bblocks_plot.gif > ps2gif.log`;

  if (-s "$src_root/cstat.gif") {
    `rsync $src_root/cstat.gif $src_html`; }
  if (-s "$src_root/c_rs.gif") {
    `rsync $src_root/c_rs.gif $src_html`; }
  if (-s "$src_root/c_rs2.gif") {
    `rsync $src_root/c_rs2.gif $src_html`; }
  if (-s "$src_root/c_rs2a.gif") {
    `rsync $src_root/c_rs2a.gif $src_html`; }

  # xsl must be in the same directory as 2mass.xml
  if (! -s "$src_html/anc_src.xsl") {
    #`ln -s ../../anc_src.xsl $src_html/anc_src.xsl`;}
    `ln -s ../../anc_src_glvary.xsl $src_html/anc_src.xsl`;}

} # while ($inline=<IN>) {
close IN;
close MAP;
#
