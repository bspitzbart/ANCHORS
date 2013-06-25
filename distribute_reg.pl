#!/usr/bin/perl
$argc = @ARGV;
$argc >= 1  or die "USAGE: distribute_reg.pl  <obsid to process>\n";

$obsid=$ARGV[0];

$src_list="calc_theta_phi_${obsid}.out";

$src_reg="src_psf_ell_${obsid}.reg";
$bkg_reg="bkg_psf_ell_${obsid}.reg";

$obsid2=$obsid;
  while (length($obsid2) < 5){
    $obsid2="0${obsid2}";
  }
$dat_path="../$obsid2/Data/obs$obsid";

open(LIS,"<$src_list");
open(SRC,"<$src_reg");
open(BKG,"<$bkg_reg");
open(RDB,">sample.rdb");

printf RDB "xray_id	redshift	ra	dec	obsid	src\n";
printf RDB "13S	8N	N	N	N	N\n";

while ($in_lis=<LIS>) {
  chomp $in_lis;
  @inline=split(/\s+/,$in_lis);
  $dat_dir=$dat_path."/src".$inline[1];
  `mkdir $dat_dir`;
  $src=<SRC>;
  chomp $src;
  $bkg=<BKG>;
  chomp $bkg;
  `echo \"$src\" > $dat_dir/src.reg`;
  `echo \"$bkg\" > $dat_dir/bkg.reg`;
  printf RDB "XS${obsid2}B".$inline[8]."_".$inline[1]."\t0.0\t";
  printf RDB $inline[6]."\t".$inline[7]."\t".$obsid."\t".$inline[1]."\n";
} # while ($in_lis=<LIS>) {

close LIS;
close SRC;
close BKG;
close RDB;
#
