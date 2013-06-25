#!/usr/bin/perl
$argc = @ARGV;
$argc >= 1  or die "USAGE: calc_theta_phi.pl  <obsid to process>\n";

$obsid=@ARGV[0];
# THE wave directory requires 5 digits
$obsid2=$obsid;
while (length($obsid2) < 5){
   $obsid2="0${obsid2}";
 }

$data_dir="/data/ANCHORS/YAXX/${obsid2}/Data/obs$obsid/";

`punlearn dmcoords`;
`pset dmcoords infile=${data_dir}/evt2_efilt.fits`;
open(IN,"<calc_theta_phi.lst");
open(OUT,">calc_theta_phi.out");

$i=1;
while (<IN>) {
  print "$i\n";
  chomp;
  @inline=split;
  `pset dmcoords ra=$inline[0]`;
  `pset dmcoords dec=$inline[1]`;
  `dmcoords option=cel celfmt=deg mode=h`;
  $theta=`pget dmcoords theta`;
  chomp $theta;
  $phi  =`pget dmcoords phi`;
  chomp $phi;
  $x   =`pget dmcoords x`;
  chomp $ra;
  $y  =`pget dmcoords y`;
  chomp $dec;
  $chip =`pget dmcoords chip_id`;
  chomp $chip;
  printf OUT " %5d %7.2f %7.2f ",$i,$x,$y;
  printf OUT "%6.2f %6.2f %12.8f %12.8f %1d\n",$theta,$phi,$inline[0],$inline[1],$chip;
  $i++;
} # while (<IN>) {
close IN;
close OUT;
#
