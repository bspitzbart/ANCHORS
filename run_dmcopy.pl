#!/usr/bin/env /proj/axaf/bin/perl
##!/opt/local/bin/perl
# run dmextract to get source counts
# $ARGV[0] is name of file which contains list of source numbers and
# RA,Dec to process
# sample.rdb

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

open(IN,"<$ARGV[0]") || die "Input file $ARGV[0] not found.\n";
$inline=<IN>; # skip first 2 header lines
$inline=<IN>; # skip first 2 header lines

`punlearn dmcopy`;

while ($inline=<IN>) {
  chomp $inline;
  @line=split(/\s+/,$inline);
  @src_str=split("_",$line[0]);
  $src=$src_str[1];
  $src_root=$data_root."/src".$src;
  `pset dmcopy infile='$src_root/acis_evt2.fits[sky=region($src_root/src.reg)]'`;
  `pset dmcopy outfile=$src_root/src_evt.fits`;
  `dmcopy mode=h clobber=yes`;
  `punlearn dmcopy`;
  `pset dmcopy infile='$src_root/acis_evt2.fits[sky=region($src_root/bkg.reg)]'`;
  `pset dmcopy outfile=$src_root/bkg_evt.fits`;
  `dmcopy mode=h clobber=yes`;

  if (! -s "$src_root/src_evt.fits") {
    print "dmcopy failed for src$src\n";
  } # if (! -s $src_root/counts.fits) {

}  #while ($inline=<IN>) {
close IN;
#
