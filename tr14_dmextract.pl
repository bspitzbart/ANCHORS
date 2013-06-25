#!/usr/bin/env /proj/axaf/bin/perl
##!/opt/local/bin/perl
# run dmextract to get source counts
# $ARGV[0] is name of file which contains list of source numbers and
# RA,Dec to process
# sample.rdb

if ($#ARGV != 2) {
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

$data_root="/data/ANCHORS/YAXX/$obs_dir/Data/obs$data_dir";
$expmap=$data_root."/".$ARGV[2];
$ap_exp=1; # apply exposure map
if (! -s "$expmap") {
  print "WARNING! exposure map $expmap not found.\n";
  $ap_exp=0;
} # if (! -s "$expmap") {

open(IN,"<$ARGV[0]") || die "Input file $ARGV[0] not found.\n";
$inline=<IN>; # skip first 2 header lines
$inline=<IN>; # skip first 2 header lines

`punlearn dmextract`;
if ($ap_exp) {
  `pset dmextract exp=$expmap`;
  `pset dmextract bkgexp=$expmap`;
}  # if ($ap_exp) {
`pset dmextract opt=generic`;

while ($inline=<IN>) {
  chomp $inline;
  @line=split(/\s+/,$inline);
  @src_str=split("_",$line[0]);
  $src=$src_str[1];
  $src_root=$data_root."/src".$src;
  $outfile=$src_root."/counts.fits";
  if (! -s "$outfile" || -M "$expmap" < -M "$outfile" || -M "$src_root/acis_evt2.fits" < -M "$outfile" || -M "$src_root/src.reg" < -M "$outfile" || -M "$src_root/bkg.reg" < -M "$outfile") {
    `pset dmextract infile='$src_root/acis_evt2.fits[bin sky=region($src_root/src.reg)]'`;
    `pset dmextract outfile=$src_root/counts.fits`;
    `pset dmextract bkg='$src_root/acis_evt2.fits[bin sky=region($src_root/bkg.reg)]'`;
    `dmextract mode=h clobber=yes`;
    # do hardness ratios
    # soft
    `pset dmextract infile='$src_root/acis_evt2.fits[bin sky=region($src_root/src.reg)][energy=300:900]'`;
    `pset dmextract outfile=$src_root/counts_sft.fits`;
    `pset dmextract bkg='$src_root/acis_evt2.fits[bin sky=region($src_root/bkg.reg)][energy=300:900]'`;
    `dmextract mode=h clobber=yes`;
    # medium
    `pset dmextract infile='$src_root/acis_evt2.fits[bin sky=region($src_root/src.reg)][energy=900:1500]'`;
    `pset dmextract outfile=$src_root/counts_med.fits`;
    `pset dmextract bkg='$src_root/acis_evt2.fits[bin sky=region($src_root/bkg.reg)][energy=900:1500]'`;
    `dmextract mode=h clobber=yes`;
    # hard
    `pset dmextract infile='$src_root/acis_evt2.fits[bin sky=region($src_root/src.reg)][energy=1500:8000]'`;
    `pset dmextract outfile=$src_root/counts_hrd.fits`;
    `pset dmextract bkg='$src_root/acis_evt2.fits[bin sky=region($src_root/bkg.reg)][energy=1500:8000]'`;
    `dmextract mode=h clobber=yes`;
  } # if (! -s $outfile

  if (! -s "$src_root/counts.fits") {
    print "dmextract failed for src$src\n";
  } # if (! -s $src_root/counts.fits) {

}  #while ($inline=<IN>) {
close IN;
#
