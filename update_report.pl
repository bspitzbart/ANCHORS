#!/usr/bin/perl

if ($#ARGV != 1) {
  die "Usage:\n  $0 <infile> <obsid>\n";
}

# usr modified
$xsl_file="/data/mta4/CVS_test/ANCHORS_PROC/mod_report2.xsl";
$xsltproc="/data/mta4/CVS_test/ANCHORS_PROC/xsltproc";

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
$outxml="/data/ANCHORS/YAXX/$obs_dir/$data_dir.xml";

$cwd=`pwd`;
open(IN,"<$ARGV[0]") || die "Input file $ARGV[0] not found.\n";
$inline=<IN>; # skip first 2 header lines
$inline=<IN>; # skip first 2 header lines
while ($inline=<IN>) {
  chomp $inline;
  @line=split(/\s+/,$inline);
  @src_str=split("_",$line[0]);
  $src=$src_str[1];
  $src_root="$data_root/src$src";
  $xml_file="src$src.xml";
  chdir($src_root);
  $command="$xsltproc -o report2.tex -param vobs $data_dir -param vsrcid $src $xsl_file $xml_file";
  #print "$command\n";
  `$command`;
  $command="latex -interaction=batchmode report2";
  #print "$command\n";
  `$command`;
  $command="dvips report2 -o report2.ps";
  #print "$command\n";
  `$command`;
  unlink(qw(report2.aux report2.dvi report2.log));
  
} # while ($inline=<IN>) {
close IN;
chdir($cwd);
#
