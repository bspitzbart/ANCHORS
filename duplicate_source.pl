#!/usr/bin/env /proj/axaf/bin/perl
##!/opt/local/bin/perl

# collect nH,kT,abund,chi^2, etc. from YAXX fits
# $ARGV[0] is name of file which contains list of source numbers and
# RA,Dec to process
# sample.rdb

if ($#ARGV != 1) {
  die "Usage:\n  $0 <infile> <obsid>\n";
}

@models=qw(bbrs);

# check obsid, directory structure is rigid
chomp $ARGV[1];
$data_dir=$ARGV[1];      #obsid
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

#!### file to list duplicate sources ###
$dup_file = "/data/ANCHORS/YAXX/$obs_dir/duplicates.txt";

#use lib '/proj/sot/ska/lib/site_perl/MST_pkgs/';
use coords;
use Astro::FITS::Header::CFITSIO;
use CFITSIO::Simple;
use Math::Trig 'great_circle_distance';
use Math::Trig 'deg2rad';
use Math::Trig 'rad2deg';

use constant PI    => 4 * atan2(1, 1);

open(IN,"<$ARGV[0]") || die "Input file $ARGV[0] not found.\n";
$inline=<IN>; # skip first 2 header lines
$inline=<IN>; # skip first 2 header lines
my @sources;
my @src_ra;
my @src_dec;
my @src_cnts;
my @src_temp;
while ($inline=<IN>) {
  chomp $inline;
  @line=split(/\s+/,$inline);
  @src_str=split("_",$line[0]);
  $src=$src_str[1];
  push @sources,$src;
  $src_root=$data_root."/src".$src;
  $ra=$line[2];
  push @src_ra,$ra;
  $dec=$line[3];
  push @src_dec,$dec;
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
  $src_name=join("",@strra).join("",@strdec);
  
  # get counts data from run_dmextract.pl output
  my $cnts=-999;
  $cnt_file="$src_root/counts.fits";
  if (-s $cnt_file) {
    my %mdl = fits_read_bintbl("$cnt_file\[Histogram\]");
    $cnts = $mdl{counts}->at(0);
    if ($cnts < 5) {
      $cntflag = 1;
    } else {
      $cntflag = 0;
    }
    push @src_cnts,$cnts;
    $bkgcnts = $mdl{bg_counts}->at(0);
    $netcnts = $mdl{net_counts}->at(0);
    $neterr = $mdl{net_err}->at(0);
    $netrate = $mdl{net_rate}->at(0);
    $area = $mdl{area}->at(0);
    $bkgarea = $mdl{bg_area}->at(0);
    $src_flux = $mdl{flux}->at(0);
    $flux = $mdl{net_flux}->at(0);
    $fluxerr = $mdl{net_flux_err}->at(0);
    $eff_area = $mdl{mean_src_exp}->at(0);
    $bg_eff_area = $mdl{mean_bg_exp}->at(0);
    $exp = $mdl{exposure}->at(0);
    #$eff_exp = 1.0/($src_flux*$eff_area/$cnts);
    `punlearn dmstat`;
    `dmstat '$data_root/evt2_efiltbin4_expmap.fits[sky=region($src_root/src.reg)]' centroid=no`;
    $exp_avg=`pget dmstat out_mean`;
    chomp $exp_avg;
    $eff_exp=$exp_avg/$eff_area;
  } #if (-s $cnt_file) {



  # calculate off-axis distance
  $off_ax = rad2deg(great_circle_distance(deg2rad($ra), deg2rad(90-$dec), deg2rad($tar_ra),deg2rad(90-$tar_dec)))*3600;

  # find ccd_id
  `punlearn dmcoords`;
  `pset dmcoords infile=$src_root/acis_evt2.fits`;
  `pset dmcoords ra=$ra`;
  `pset dmcoords dec=$dec`;
  `dmcoords celfmt=deg option=cel mode=h`;
  $chip =`pget dmcoords chip_id`;
  chomp $chip;

  my $quant_file="$data_root/src$src/quantile.dat"; # ddchange
  open (QUANT,"<$quant_file");
  $qinline=<QUANT>; # skip first line
  $qinline=<QUANT>;
  chomp $qinline;
  @qline=split(/\s+/,$qinline);

  my $bbrs_nh=-999;
  my $bbrs_nh_err=-999;
  my $bbrs_kt=-999;
  my $bbrs_kt_err=-999;
  my $bbrs_kt_flux=-999;
  my $bbrs_abund=-999;
  my $bbrs_abund_err=-999;
  my $bbrs_chi=-999;
  my $bbrs_dof=-999;
  my $bbrs_flux=-999;
  my $mdl_file="$data_root/src$src/bbrs.mdl"; # ddchange
  if (-s $mdl_file) {
    my $mdl_header = fits_read_hdr("$mdl_file", "MDL_Models");
    my %mdl = fits_read_bintbl("$mdl_file\[MDL_Models\]");
    my $columns = join(" ",keys(%mdl));
    if ($columns =~ m/parvalue/) {
      $bbrs_nh = $mdl{parvalue}->at(2);
      $bbrs_kt = $mdl{parvalue}->at(4);
      if ($bbrs_kt < 15) {
	$bbrs_kt_flg = 0;
      } else {
	$bbrs_kt_flg = 1;
      }
    }

  #!### put bbkt into array for all sources ###
  push @src_temp,$bbrs_kt;
  }
}
close IN;


open(OUT,">$dup_file");

#!### run sources through a loop to test for duplicate sources ###
#!### $ii is source of interest; $jj is for all the other sources against which it is being tested ###
$num_srcs = @src_dec;
my @dup_src;
printf OUT "Source ID   # Duplicate Sources   Duplicate Source IDs\n";
for ($ii = 0; $ii < $num_srcs; $ii++) {
  for ($jj = 0; $jj < $num_srcs; $jj++) {
    if ($ii != $jj) {
      $sep_ang = rad2deg(great_circle_distance(deg2rad($src_ra[$jj]), deg2rad(90-$src_dec[$jj]), deg2rad($src_ra[$ii]),deg2rad(90-$src_dec[$jj])))*3600;
      ##      $cos_sep_ang = cos(PI/2-(PI/180)*$src_dec[$ii])*cos(PI/2-(PI/180)*$src_dec[$jj])+sin(PI/2-(PI/180)*$src_dec[$ii])*sin(PI/2-(PI/180)*$src_dec[$jj])*cos($src_ra[$ii]-$src_ra[$jj]);
      #     $sep_ang = (180/PI)*acos($cos_sep_ang);
      if (($sep_ang < 1) && ($src_cnts[$ii] != 0)) {
	$cnts_diff = abs($src_cnts[$ii] - $src_cnts[$jj])/$src_cnts[$ii];
	if (($cnts_diff < 0.10) && ($src_temp[$ii] != 0)) {
	  $kt_diff = abs($src_temp[$ii] - $src_temp[$jj])/$src_temp[$ii];
	  if ($kt_diff < 0.10) {
	    push @dup_src,$sources[$jj];
	  }
	}
      }
    }
  }
  $num_dup = @dup_src;
  printf OUT "$sources[$ii]                    $num_dup                        @dup_src\n";
  @dup_src = ();
}
close OUT;
