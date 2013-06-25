#!/usr/bin/perl
# convert xml into html:
#  make top level html page for each obsid

# usr modified
$prog_dir="/data/ANCHORS/YAXX/bin_linux";
$prog_dat="/data/ANCHORS/YAXX/Data";
$xsl_file="$prog_dat/anc_obs.xsl";
$xsl_path="$prog_dat";
#test#$xsl_path="/data/ANCHORS/YAXX/CVS_test/ANCHORS/";
$xsltproc="$prog_dir/xsltproc";

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
# put output files here:
$out_root="/proj/web-cxc-dmz/htdocs/ANCHORS/$obs_dir";
#test#$out_root=".";

open(TOTXML,">tot.xml");
print TOTXML "<\?xml version=\"1.0\" encoding=\"ISO-8859-1\"\?>\n";
print TOTXML "<\?xml-stylesheet type=\"text/xsl\" href=\"../../anc_obs.xsl\"\?>\n";
print TOTXML "<root>\n";
print TOTXML "<OBS>\n";

$xml_file="$data_root/../../$data_dir.xml";
open(INXML,"<$xml_file");
$sect=0;
while(<INXML>) {
  if ( $_ =~ m/<\/OBS>/) { $sect=0; }
  if ($sect) {print TOTXML $_;}
  if ( $_ =~ m/<OBS>/) { $sect=1; }
} # while(<INXML>) {
close INXML;

open(IN,"<$ARGV[0]") || die "Input file $ARGV[0] not found.\n";
$inline=<IN>; # skip first 2 header lines
$inline=<IN>; # skip first 2 header lines
while ($inline=<IN>) {
  chomp $inline;
  @line=split(/\s+/,$inline);
  @src_str=split("_",$line[0]);
  $src=$src_str[1];
  $src_root="$data_root/src$src";
  $xml_file="$src_root/src$src.xml";

  $sect=0;
  open(INXML,"<$xml_file");
  while (<INXML>) {
    if ($_ =~ m/<\/SOURCE>/) {
      print TOTXML $_;
      $sect=0;
    }
    if ($_ =~ m/<SOURCE/) {
      $sect=1;
    }
    if ($sect) { print TOTXML $_;}
  } # while (<INXML>) {
  close INXML;
} # while ($inline=<IN>) {
    
print TOTXML "</OBS>\n";
print TOTXML "</root>\n";
close TOTXML;
$command="$xsltproc -o $out_root/obs.html -param sortcol \"id\" $xsl_path/anc_obs_id.xsl tot.xml";
print "$command\n";
@trap=`$command`;
$command="$xsltproc -o $out_root/obs_cnts.html -param sortcol \"cnts\" $xsl_path/anc_obs_cnts.xsl tot.xml";
print "$command\n";
@trap=`$command`;
$command="$xsltproc -o $out_root/obs_bb.html -param sortcol \"bb\" $xsl_path/anc_obs_bblocks.xsl tot.xml";
print "$command\n";
@trap=`$command`;

# which model makes these harder
#$command="$xsltproc -o $out_root/obs_nh.html -param sortcol \"nh\" $xsl_path tot.xml";
#$command="$xsltproc -o $out_root/obs_kt.html -param sortcol \"kt\" $xsl_path tot.xml";
#$command="$xsltproc -o $out_root/obs_kt2.html -param sortcol \"kt2\" $xsl_path tot.xml";
#$command="$xsltproc -o $out_root/obs_chi.html -param sortcol \"chi\" $xsl_path tot.xml";
#
