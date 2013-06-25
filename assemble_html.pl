#!/usr/bin/perl
# convert xml into html:

# usr modified
$prog_dir="/data/ANCHORS/YAXX/bin";
$prog_dat="/data/ANCHORS/YAXX/Data";
$xsl_file="$prog_dat/assemble_html.xsl";
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

open(OUTTOP,">$out_root/$data_dir.html");
$xml_file="$data_root/../../$data_dir.xml";
$command="$xsltproc -param vobs $data_dir -param vsect \"\'top\'\" $xsl_file $xml_file";
@trap=`$command`;
for ($itrap=0;$itrap<=$#trap;$itrap++) {
  print OUTTOP "$trap[$itrap]";
}
print OUTTOP "\n";

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
  $src_name=anc_name($

  $command="$xsltproc -param vobs $data_dir -param vsrcid $src -param vsect \"\'top\'\" $xsl_file $xml_file";
  ##c#print "$command\n";
  @trap=`$command`;
  for ($itrap=0;$itrap<=$#trap;$itrap++) {
    chomp $trap[$itrap];
    $trap[$itrap]=~s/\s+//;
    print OUTTOP "$trap[$itrap]";
  }
  print OUTTOP "\n";

  $command="$xsltproc -param vobs $data_dir -param vsrcid $src -param vsect \"\'spec\'\" $xsl_file $xml_file";
  ##c#print "$command\n";
  @trap=`$command`;
  for ($itrap=0;$itrap<=$#trap;$itrap++) {
    chomp $trap[$itrap];
    $trap[$itrap]=~s/\s+//;
    print OUTSPEC $trap[$itrap];
  }
  print OUTSPEC "\n";

  $command="$xsltproc -param vobs $data_dir -param vsrcid $src -param vsect \"\'bblocks\'\" $xsl_file $xml_file";
  ##c#print "$command\n";
  @trap=`$command`;
  for ($itrap=0;$itrap<=$#trap;$itrap++) {
    chomp $trap[$itrap];
    $trap[$itrap]=~s/\s+//;
    print OUTBBLK $trap[$itrap];
  }
  print OUTBBLK "\n";

} # while ($inline=<IN>) {
close IN;
close OUTTOP;
close OUTBBLK;
close OUTSPEC;
#
