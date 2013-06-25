#!/usr/bin/env /proj/axaf/bin/perl
##!/opt/local/bin/perl
# run dmextract to get source counts
# $ARGV[0] is name of file which contains list of source numbers and
# RA,Dec to process
# sample.rdb

if ($#ARGV != 1) {
  die "Usage:\n  $0 <infile> <obsid> <expmap>\n";
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

$data_root="/data/mta4/AExtract/YAXX/$obs_dir/Data/obs$data_dir";
#$expmap=$data_root."/".$ARGV[2];
#if (! -s "$expmap") {
  #die "exposure map $expmap not found.\n";
#} # if (! -s "$expmap") {

open(IN,"<$ARGV[0]") || die "Input file $ARGV[0] not found.\n";
$inline=<IN>; # skip first 2 header lines
$inline=<IN>; # skip first 2 header lines

`punlearn dmextract`;
#`pset dmextract exp=$expmap`;
#`pset dmextract bkgexp=$expmap`;
`pset dmextract opt=generic`;

while ($inline=<IN>) {
  chomp $inline;
  @line=split(/\s+/,$inline);
  @src_str=split("_",$line[0]);
  $src=$src_str[1];
  $src_root=$data_root."/src".$src;
  `pset dmextract infile='$src_root/acis_evt2.fits[bin sky=region($src_root/src.reg)]'`;
  `pset dmextract outfile=$src_root/counts_noexp.fits`;
  `pset dmextract bkg='$src_root/acis_evt2.fits[bin sky=region($src_root/bkg.reg)]'`;
  `dmextract mode=h`;

  if (! -s "$src_root/counts.fits") {
    print "dmextract failed for src$src\n";
  } # if (! -s $src_root/counts.fits) {

}  #while ($inline=<IN>) {
close IN;
#
