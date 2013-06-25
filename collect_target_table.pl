#!/usr/bin/perl
##!/opt/local/bin/perl
# collect nH,kT,abund,chi^2, etc. from YAXX fits
# $ARGV[0] is name of file which contains list of source numbers and
# RA,Dec to process
# sample.rdb
#
if ($#ARGV != 2) {
  die "Usage:\n  $0 <infile> <obsid> <expmap>\n";
}

@models=qw(c_rs);

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
$outxml="/data/ANCHORS/YAXX/$obs_dir/$data_dir.xml";
$html_root="./";
$bbsig="95.02";  # bblocks significance

use lib '/proj/sot/ska/lib/perl';
use coords;
use Astro::FITS::Header::CFITSIO;
use CFITSIO::Simple;
use Math::Trig 'great_circle_distance';
use Math::Trig 'deg2rad';
use Math::Trig 'rad2deg';
use XDB qw(time_check);
use FileSysProc qw(ops_open);
use CIAO;
use OutputText;
use Parameter;
use Expect;
use CXC::Envs;
use CXC::Archive;

open(IN,"<$ARGV[0]") || die "Input file $ARGV[0] not found.\n";
if (-s $outxml) {
  print "Overwriting $outxml\n";
  open(OUT,">$outxml");
  #die "Cannot overwrite $outxml.\n";
} else {
  open(OUT,">$outxml");
} # if (! -s $outxml) {


#****** read target data ****
$inline=<IN>; # skip first 2 header lines
$inline=<IN>; # skip first 2 header lines
$inline=<IN>;
close IN;
chomp $inline;
@line=split(/\s+/,$inline);
@src_str=split("_",$line[0]);
$src=$src_str[1];
$evt_file="$data_root/src$src/acis_evt2.fits"; #ddchange
my $evt_header = fits_read_hdr("$evt_file", "EVENTS");
$tar_obs = $evt_header->{OBS_ID};
$tar_tstart = $evt_header->{TSTART};
$tar_seq = $evt_header->{SEQ_NUM};
$tar_date = $evt_header->{"DATE-OBS"};
$tar_ins = $evt_header->{DETNAM};
$tar_nam = $evt_header->{OBJECT};
$tar_exp = $evt_header->{EXPOSURE}/1000;
$tar_ra = $evt_header->{RA_NOM};
$tar_dec = $evt_header->{DEC_NOM};
($ra_str,$dec_str)=&dec2seg($tar_ra,$tar_dec);
$simbad_id = $ra_str."+".$dec_str;
$simbad_id =~ s/\:/\+/g;
print OUT "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\n";
print OUT "<?xml-stylesheet type=\"text/xsl\" href=\"..\/..\/anc_obs.xsl\"?>\n";
print OUT "<root>\n";
print OUT "<OBS>\n";
print OUT "  <OBSID>$tar_obs</OBSID>\n";
print OUT "  <NAME>$tar_nam</NAME>\n";
printf OUT "  <TSTART>%.8e</TSTART>\n",$tar_tstart;
printf OUT "  <EXPTIME units=\"ks\">%7.3f</EXPTIME>\n",$tar_exp;
print OUT "  <SEQ>$tar_seq</SEQ>\n";
print OUT "  <INST>$tar_ins</INST>\n";
print OUT "  <DATE>$tar_date</DATE>\n";
print OUT "  <AIMPOINT>($tar_ra,$tar_dec)</AIMPOINT>\n";
print OUT "  <SIMBAD_ID>$simbad_id</SIMBAD_ID>\n";
$date=`date`;
chomp $date;
print OUT "  <created>$date</created>\n";
print OUT "</OBS>\n";
print OUT "</root>\n";
close OUT;

open(IN,"<$ARGV[0]") || die "Input file $ARGV[0] not found.\n";
$inline=<IN>; # skip first 2 header lines
$inline=<IN>; # skip first 2 header lines
while ($inline=<IN>) {
  chomp $inline;
  @line=split(/\s+/,$inline);
  @src_str=split("_",$line[0]);
  $src=$src_str[1];
  $src_root=$data_root."/src".$src;
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
  $src_name=join("",@strra).join("",@strdec);
 
  # get counts data from run_dmextract.pl output
  my $cnts=-999;
  $cnt_file="$src_root/counts.fits";
  if (-s $cnt_file) {
    my %mdl = fits_read_bintbl("$cnt_file\[Histogram\]");


    # calculate off-axis distance (arcsec)
    $off_ax = rad2deg(great_circle_distance(deg2rad($ra), deg2rad(90-$dec), deg2rad($tar_ra),deg2rad(90-$tar_dec)))*3600;

    $cnts = $mdl{counts}->at(0);
    $bkgcnts = $mdl{bg_counts}->at(0);
    $netcnts = $mdl{net_counts}->at(0);

    #!### low counts warning: 5 cts on-axis (w/in 4'); 10 cts off-axis
    my $cts_cutoff = 5.;
    if ($off_ax > 240.) {
      $cts_cutoff = 10.;
    }
    if ($netcnts < $cts_cutoff) {
      $cntflag = 1;
    } else {
      $cntflag = 0;
    }
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

    #!### Pileup test: Global Grade (0=none, 1=mild, 2=severe) ###
    #!### only run if off-axis distance is less than 4' #!###
    $cntrate = $cnts/$exp;
    if (($cntrate < 0.01) || ($off_ax >= 240.)) {
      $gbl_pflg = 0;
    } elsif (($cntrate < 0.05) && ($cntrate >= 0.01)) {
      $gbl_pflg = 1;
    } elsif ($cntrate >= 0.05) {
      $gbl_pflg = 2;
    }
#    print "$cnts $cntrate $exp  $gbl_pflg\n";

    #$eff_exp = 1.0/($src_flux*$eff_area/$cnts);
    `punlearn dmstat`;
    `dmstat '$expmap\[sky=region($src_root/src.reg)]' centroid=no`;
    $exp_avg=`pget dmstat out_mean`;
    chomp $exp_avg;
    if ($eff_area > 0) {
      $eff_exp=$exp_avg/$eff_area;
    } else {
      $eff_exp=0;
    }
#    print "$exp $exp_avg $eff_area $eff_exp\n";
  } #if (-s $cnt_file) {
  $outfile="$data_root/src$src/src$src.xml";
  open(OUT,">$outfile");
  print OUT "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\n";
  #print OUT "<?xml-stylesheet type=\"text/xsl\" href=\"..\/..\/anc_src.xsl\"?>\n";
  print OUT "<?xml-stylesheet type=\"text/xsl\" href=\"anc_src.xsl\"?>\n";
  print OUT "<root>\n";
  print OUT "<SOURCE id=\"$src\">\n";
  print OUT "  <ID>$src</ID>";
  print OUT "  <NAME>$src_name</NAME>\n";
  printf OUT "  <RA str=\"$ra_str\">%10.5f</RA>\n",$ra;
  printf OUT "  <DEC str=\"$dec_str\">%10.5f</DEC>\n",$dec;
  printf OUT "  <CNTS>%6.1f</CNTS><AREA>%7.1f</AREA>\n",$cnts,$area;
  printf OUT "  <CNTFLAG>%1d</CNTFLAG>\n",$cntflag;
  #make tag - count flag (0 or 1)
  printf OUT "  <BG_CNTS>%6.1f</BG_CNTS>",$bkgcnts;
  printf OUT "<BG_AREA>%7.1f</BG_AREA>\n",$bkgarea;
  printf OUT "  <NET_CNTS>%6.1f</NET_CNTS>",$netcnts;
  printf OUT "<NET_ERR>%6.1f</NET_ERR>\n",$neterr;
  printf OUT "  <NET_FLUX>%.2e</NET_FLUX>\n",$flux;
  printf OUT "  <NET_FLUX_ERR>%.2e</NET_FLUX_ERR>\n",$fluxerr;
  printf OUT "  <EFF_AREA>%6.2f</EFF_AREA>\n",$eff_area;
  printf OUT "  <BG_EFF_AREA>%6.2f</BG_EFF_AREA>\n",$bg_eff_area;
  printf OUT "  <EXP>%8.1f</EXP>\n",$eff_exp;
  printf OUT "  <OFF_AX>%5.1f</OFF_AX>\n",$off_ax;

  # find ccd_id
  `punlearn dmcoords`;
  `pset dmcoords infile=$src_root/acis_evt2.fits`;
  `pset dmcoords ra=$ra`;
  `pset dmcoords dec=$dec`;
  `dmcoords celfmt=deg option=cel mode=h`;
  $chip =`pget dmcoords chip_id`;
  chomp $chip;
  printf OUT "  <CCD_ID>%d</CCD_ID>\n",$chip;

  my $quant_file="$data_root/src$src/quantile.dat"; # ddchange
  open (QUANT,"<$quant_file");
  $qinline=<QUANT>; # skip first line
  $qinline=<QUANT>;
  chomp $qinline;
  @qline=split(/\s+/,$qinline);
  printf OUT "  <E25>%6.3f</E25><E25_err>%6.3f</E25_err>\n",$qline[1],$qline[2];
  printf OUT "  <E50>%6.3f</E50><E50_err>%6.3f</E50_err>\n",$qline[3],$qline[4];
  printf OUT "  <E75>%6.3f</E75><E75_err>%6.3f</E75_err>\n",$qline[5],$qline[6];
  printf OUT "  <Q25>%6.3f</Q25><Q25_err>%6.3f</Q25_err>\n",($qline[1]-0.3)/7.7,abs(($qline[2])/7.7);
  printf OUT "  <Q50>%6.3f</Q50><Q50_err>%6.3f</Q50_err>\n",($qline[3]-0.3)/7.7,abs(($qline[4])/7.7);
  printf OUT "  <Q75>%6.3f</Q75><Q75_err>%6.3f</Q75_err>\n",($qline[5]-0.3)/7.7,abs(($qline[6])/7.7);

  # extract and calculate hardness ratios
  my $sft_cnts=-999;
  $cnt_file="$src_root/counts_sft.fits";
  if (-s $cnt_file) {
    my %mdl = fits_read_bintbl("$cnt_file\[Histogram\]");
    $sft_netcnts = $mdl{net_counts}->at(0);
    $sft_neterr = $mdl{net_err}->at(0);
  }
  my $med_cnts=-999;
  $cnt_file="$src_root/counts_med.fits";
  if (-s $cnt_file) {
    my %mdl = fits_read_bintbl("$cnt_file\[Histogram\]");
    $med_netcnts = $mdl{net_counts}->at(0);
    $med_neterr = $mdl{net_err}->at(0);
  }
  my $hrd_cnts=-999;
  $cnt_file="$src_root/counts_hrd.fits";
  if (-s $cnt_file) {
    my %mdl = fits_read_bintbl("$cnt_file\[Histogram\]");
    $hrd_netcnts = $mdl{net_counts}->at(0);
    $hrd_neterr = $mdl{net_err}->at(0);
  }
  $hr1=-999;
  $hr2=-999;
  $hr3=-999;
  if ($hrd_netcnts > 0 && $med_netcnts > 0) {
    $hr1=($hrd_netcnts-$med_netcnts)/($hrd_netcnts+$med_netcnts);
  }
  if ($med_netcnts > 0 && $sft_netcnts > 0) {
    $hr2=($med_netcnts-$sft_netcnts)/($med_netcnts+$sft_netcnts);
  }
  if ($hrd_netcnts > 0 && $sft_netcnts > 0) {
    $hr3=($hrd_netcnts-$sft_netcnts)/($hrd_netcnts+$sft_netcnts);
  }
  printf OUT "  <HRD_CNTS>%.2f</HRD_CNTS>",$hrd_netcnts;
  printf OUT "<HRD_ERR>%.2f</HRD_ERR>\n",$hrd_neterr;
  printf OUT "  <MED_CNTS>%.2f</MED_CNTS>",$med_netcnts;
  printf OUT "<MED_ERR>%.2f</MED_ERR>\n",$med_neterr;
  printf OUT "  <SFT_CNTS>%.2f</SFT_CNTS>",$sft_netcnts;
  printf OUT "<SFT_ERR>%.2f</SFT_ERR>\n",$sft_neterr;
  printf OUT "  <HR1>%.4f</HR1>\n",$hr1;
  printf OUT "  <HR2>%.4f</HR2>\n",$hr2;
  printf OUT "  <HR3>%.4f</HR3>\n",$hr3;

  print OUT "  <SPECTRA>\n";
  my $c_rs_nh=-999;
  my $c_rs_nh_err=-999;
  my $c_rs_kt=-999;
  my $c_rs_kt_err=-999;
  my $c_rs_kt_flux=-999;
  my $c_rs_abund=-999;
  my $c_rs_abund_err=-999;
  my $c_rs_chi=-999;
  my $c_rs_dof=-999;
  my $c_rs_flux=-999;
  my $mdl_file="$data_root/src$src/c_rs.mdl"; # ddchange
  if (-s $mdl_file) {
    my $mdl_header = fits_read_hdr("$mdl_file", "MDL_Models");
    my %mdl = fits_read_bintbl("$mdl_file\[MDL_Models\]");
    my $columns = join(" ",keys(%mdl));
    if ($columns =~ m/parvalue/) {
      $c_rs_nh = $mdl{parvalue}->at(2);
      $c_rs_kt = $mdl{parvalue}->at(4);
      if ($c_rs_kt < 15) {
	$c_rs_kt_flg = 0;
      } else {
	$c_rs_kt_flg = 1;
      }
      $c_rs_kt_norm = $mdl{parvalue}->at(7);
      $c_rs_abund = $mdl{parvalue}->at(5);
    } # if ($columns =~ m/parvalue/) {
    if ($columns =~ m/unc_upper/) {
      $c_rs_nh_err = $mdl{unc_upper}->at(2);
      $c_rs_kt_err = $mdl{unc_upper}->at(4);
      $c_rs_abund_err = $mdl{unc_upper}->at(5);
    } # if ($columns =~ m/unc_upper/) {
    $c_rs_chi = $mdl_header->{F_RSTAT};
    if (($c_rs_chi < 2) && ($c_rs_chi > 0.2)) {
      $c_rs_chi_flg = 0;
    } else {
      $c_rs_chi_flg = 1;
    }
    $c_rs_dof = $mdl_header->{F_DOF};
    $c_rs_flux = $mdl_header->{EFLUX};
    $c_rs_kt_flux = $mdl_header->{EFLUX1};
    #$command="dmlist '".$mdl_file."[MDL_Models]' header | grep flux_rs1";
    #@eflux=`$command`;
    #@eflux_str=split(" ",$eflux[0]);
    #$c_rs_kt_flux = $eflux_str[2];
    $c_rs_flg = $c_rs_kt_flg + $c_rs_chi_flg;
    if ($c_rs_flg != 0) {
      $c_rs_flg = 1;
    }
    
    print OUT "    <MODEL name=\'c_rs\'>\n";
    printf OUT "      <NH>%.2f</NH>\n", $c_rs_nh;
    printf OUT "      <NH_ERR>%.2f</NH_ERR>\n", $c_rs_nh_err;
    printf OUT "      <KT>%.2f</KT>\n", $c_rs_kt;
    printf OUT "      <KT_ERR>%.2f</KT_ERR>\n", $c_rs_kt_err;
    printf OUT "      <KT_FLUX>%.2e</KT_FLUX>\n", $c_rs_kt_flux;
    printf OUT "      <KT_NORM>%.2e</KT_NORM>\n", $c_rs_kt_norm;
    printf OUT "      <KT_FLG>%1d</KT_FLG>\n", $c_rs_kt_flg;
    printf OUT "      <ABUND>%.2f</ABUND>\n", $c_rs_abund;
    printf OUT "      <ABUND_ERR>%.2f</ABUND_ERR>\n", $c_rs_abund_err;
    printf OUT "      <CHI>%.2f</CHI>\n", $c_rs_chi;
    printf OUT "      <CHI_FLG>%1d</CHI_FLG>\n",$c_rs_chi_flg;
    printf OUT "      <DOF>%d</DOF>\n", $c_rs_dof;
    printf OUT "      <FLUX>%.2e</FLUX>\n", $c_rs_flux;
    printf OUT "      <FIT_FLG>%1d</FIT_FLG>\n", $c_rs_flg;
    print OUT "    </MODEL>\n";
  } # if (-s $mdl_file) {

  my $c_rs2_nh=-999;
  my $c_rs2_nh_err=-999;
  my $c_rs2_kt=-999;
  my $c_rs2_kt_err=-999;
  my $c_rs2_abund=-999;
  my $c_rs2_abund_err=-999;
  my $c_rs2_chi=-999;
  my $c_rs2_dof=-999;
  my $c_rs2_flux=-999;
  my $kt_flux=-999;
  my $mdl_file="$data_root/src$src/c_rs2.mdl"; # ddchange
  if (-s $mdl_file) {
    my $mdl_header = fits_read_hdr("$mdl_file", "MDL_Models");
    my %mdl = fits_read_bintbl("$mdl_file\[MDL_Models\]");
    my $columns = join(" ",keys(%mdl));
    if ($columns =~ m/parvalue/) {
      $c_rs2_nh = $mdl{parvalue}->at(2);
      $c_rs2_kt = $mdl{parvalue}->at(4);
      if ($c_rs2_kt < 15) {
	$c_rs2_kt_flg = 0;
      } else {
	$c_rs2_kt_flg = 1;
      }
      $c_rs2_kt_norm = $mdl{parvalue}->at(7);
      $c_rs2_kt2 = $mdl{parvalue}->at(9);
      if ($c_rs2_kt2 < 15) {
	$c_rs2_kt2_flg = 0;
      } else {
	$c_rs2_kt2_flg = 1;
      } 
      $c_rs2_kt2_norm = $mdl{parvalue}->at(12);
      $c_rs2_abund = $mdl{parvalue}->at(5);
    } # if ($columns =~ m/parvalue/) {
    if ($columns =~ m/unc_upper/) {
      $c_rs2_nh_err = $mdl{unc_upper}->at(2);
      $c_rs2_kt_err = $mdl{unc_upper}->at(4);
      $c_rs2_kt2_err = $mdl{unc_upper}->at(9);
      $c_rs2_abund_err = $mdl{unc_upper}->at(5);
    } # if ($columns =~ m/unc_upper/) {
    $c_rs2_chi = $mdl_header->{F_RSTAT};
    if (($c_rs2_chi < 2) && ($c_rs2_chi > 0.2)) {
      $c_rs2_chi_flg = 0;
    } else {
      $c_rs2_chi_flg = 1;
    }
    $c_rs2_dof = $mdl_header->{F_DOF};
    $c_rs2_flux = $mdl_header->{EFLUX};
    $c_rs2_kt1_flux = $mdl_header->{EFLUX1};
    $c_rs2_kt2_flux = $mdl_header->{EFLUX2};
    #$command="dmlist '".$mdl_file."[MDL_Models]' header | grep flux_rs1";
    #@eflux=`$command`;
    #@eflux_str=split(" ",$eflux[0]);
    #$c_rs2_kt1_flux = $eflux_str[2];
    #$command="dmlist '".$mdl_file."[MDL_Models]' header | grep flux_rs2";
    #@eflux=`$command`;
    #@eflux_str=split(" ",$eflux[0]);
    #$c_rs2_kt2_flux = $eflux_str[2];
    $c_rs2_flg = $c_rs2_kt_flg + $c_rs2_kt2_flg + $c_rs2_chi_flg;
    if ($c_rs2_flg != 0) {
      $c_rs2_flg = 1;
    }
    print OUT "    <MODEL name=\'c_rs2\'>\n";
    printf OUT "      <NH>%.2f</NH>\n", $c_rs2_nh;
    printf OUT "      <NH_ERR>%.2f</NH_ERR>\n", $c_rs2_nh_err;
    printf OUT "      <KT>%.2f</KT>\n", $c_rs2_kt;
    printf OUT "      <KT_ERR>%.2f</KT_ERR>\n", $c_rs2_kt_err;
    printf OUT "      <KT_FLUX>%.2e</KT_FLUX>\n", $c_rs2_kt1_flux;
    printf OUT "      <KT_NORM>%.2e</KT_NORM>\n", $c_rs2_kt_norm;
    printf OUT "      <KT_FLG>%1d</KT_FLG>\n", $c_rs2_kt_flg;
    printf OUT "      <KT2>%.2f</KT2>\n", $c_rs2_kt2;
    printf OUT "      <KT2_ERR>%.2f</KT2_ERR>\n", $c_rs2_kt2_err;
    printf OUT "      <KT2_FLUX>%.2e</KT2_FLUX>\n", $c_rs2_kt2_flux;
    printf OUT "      <KT2_NORM>%.2e</KT2_NORM>\n", $c_rs2_kt2_norm;
    printf OUT "      <KT2_FLG>%1d</KT2_FLG>\n", $c_rs2_kt2_flg;
    printf OUT "      <ABUND>%.2f</ABUND>\n", $c_rs2_abund;
    printf OUT "      <ABUND_ERR>%.2f</ABUND_ERR>\n", $c_rs2_abund_err;
    printf OUT "      <CHI>%.2f</CHI>\n", $c_rs2_chi;
    printf OUT "      <CHI_FLG>%1d</CHI_FLG>\n",$c_rs2_chi_flg;
    printf OUT "      <DOF>%d</DOF>\n", $c_rs2_dof;
    printf OUT "      <FLUX>%.2e</FLUX>\n", $c_rs2_flux;
    printf OUT "      <FIT_FLG>%1d</FIT_FLG>\n", $c_rs2_flg;
    print OUT "    </MODEL>\n";
  } # if (-s $mdl_file) {

  my $c_rs2a_nh=-999;
  my $c_rs2a_nh_err=-999;
  my $c_rs2a_kt=-999;
  my $c_rs2a_kt_err=-999;
  my $c_rs2a_kt_flux=-999;
  my $c_rs2a_kt2=-999;
  my $c_rs2a_kt2_err=-999;
  my $c_rs2a_kt2_flux=-999;
  my $c_rs2a_abund=-999;
  my $c_rs2a_abund_err=-999;
  my $c_rs2a_chi=-999;
  my $c_rs2a_dof=-999;
  my $c_rs2a_flux=-999;
  my $mdl_file="$data_root/src$src/c_rs2a.mdl"; # ddchange
  if (-s $mdl_file) {
    $mdl_header = fits_read_hdr("$mdl_file", "MDL_Models");
    %mdl = fits_read_bintbl("$mdl_file\[MDL_Models\]");
    my $columns = join(" ",keys(%mdl));
    if ($columns =~ m/parvalue/) {
      $c_rs2a_nh = $mdl{parvalue}->at(2);
      $c_rs2a_kt = $mdl{parvalue}->at(4);
      if ($c_rs2a_kt < 15) {
	$c_rs2a_kt_flg = 0;
      } else {
	$c_rs2a_kt_flg = 1;
      } 
      $c_rs2a_kt_norm = $mdl{parvalue}->at(7);
      $c_rs2a_kt2 = $mdl{parvalue}->at(9);
            if ($c_rs2a_kt2 < 15) {
	$c_rs2a_kt2_flg = 0;
      } else {
	$c_rs2a_kt2_flg = 1;
      } 
      $c_rs2a_kt2_norm = $mdl{parvalue}->at(12);
      $c_rs2a_abund = $mdl{parvalue}->at(5);
    } # if ($columns =~ m/parvalue/) {
    if ($columns =~ m/unc_upper/) {
      $c_rs2a_nh_err = $mdl{unc_upper}->at(2);
      $c_rs2a_kt_err = $mdl{unc_upper}->at(4);
      $c_rs2a_kt2_err = $mdl{unc_upper}->at(9);
      $c_rs2a_abund_err = $mdl{unc_upper}->at(5);
    } # if ($columns =~ m/unc_upper/) {
    $c_rs2a_chi = $mdl_header->{F_RSTAT};
    if (($c_rs2a_chi < 2) && ($c_rs2_chi > 0.2)) {
      $c_rs2a_chi_flg = 0;
    } else {
      $c_rs2a_chi_flg = 1;
    }
    $c_rs2a_dof = $mdl_header->{F_DOF};
    $c_rs2a_flux = $mdl_header->{EFLUX};
    $c_rs2a_kt1_flux = $mdl_header->{EFLUX1};
    $c_rs2a_kt2_flux = $mdl_header->{EFLUX2};
    #$command="dmlist '".$mdl_file."[MDL_Models]' header | grep flux_rs1";
    #@eflux=`$command`;
    #@eflux_str=split(" ",$eflux[0]);
    #$c_rs2a_kt1_flux = $eflux_str[2];
    #$command="dmlist '".$mdl_file."[MDL_Models]' header | grep flux_rs2";
    #@eflux=`$command`;
    #@eflux_str=split(" ",$eflux[0]);
    #$c_rs2a_kt2_flux = $eflux_str[2];
    $c_rs2a_flg = $c_rs2a_kt_flg + $c_rs2a_kt2_flg + $c_rs2a_chi_flg;
    if ($c_rs2a_flg != 0) {
      $c_rs2a_flg = 1;
    }
    print OUT "    <MODEL name=\'c_rs2a\'>\n";
    printf OUT "      <NH>%.2f</NH>\n", $c_rs2a_nh;
    printf OUT "      <NH_ERR>%.2f</NH_ERR>\n", $c_rs2a_nh_err;
    printf OUT "      <KT>%.2f</KT>\n", $c_rs2a_kt;
    printf OUT "      <KT_ERR>%.2f</KT_ERR>\n", $c_rs2a_kt_err;
    printf OUT "      <KT_FLUX>%.2e</KT_FLUX>\n", $c_rs2a_kt1_flux;
    printf OUT "      <KT_NORM>%.2e</KT_NORM>\n", $c_rs2a_kt_norm;
    printf OUT "      <KT_FLG>%1d</KT_FLG>\n", $c_rs2a_kt_flg;
    printf OUT "      <KT2>%.2f</KT2>\n", $c_rs2a_kt2;
    printf OUT "      <KT2_ERR>%.2f</KT2_ERR>\n", $c_rs2a_kt2_err;
    printf OUT "      <KT2_FLUX>%.2e</KT2_FLUX>\n", $c_rs2a_kt2_flux;
    printf OUT "      <KT2_NORM>%.2e</KT2_NORM>\n", $c_rs2a_kt2_norm;
    printf OUT "      <KT2_FLG>%1d</KT2_FLG>\n", $c_rs2a_kt2_flg;
    printf OUT "      <ABUND>%.2f</ABUND>\n", $c_rs2a_abund;
    printf OUT "      <ABUND_ERR>%.2f</ABUND_ERR>\n", $c_rs2a_abund_err;
    printf OUT "      <CHI>%.2f</CHI>\n", $c_rs2a_chi;
    printf OUT "      <CHI_FLG>%1d</CHI_FLG>\n",$c_rs2a_chi_flg;
    printf OUT "      <DOF>%d</DOF>\n", $c_rs2a_dof;
    printf OUT "      <FLUX>%.2e</FLUX>\n", $c_rs2a_flux;
    printf OUT "      <FIT_FLG>%1d</FIT_FLG>\n", $c_rs2a_flg;
    print OUT "    </MODEL>\n";
  } # if (-s $mdl_file) {

  my $c_ap_nh=-999;
  my $c_ap_nh_err=-999;
  my $c_ap_kt=-999;
  my $c_ap_kt_err=-999;
  my $c_ap_kt_flux=-999;
  my $c_ap_abund=-999;
  my $c_ap_abund_err=-999;
  my $c_ap_chi=-999;
  my $c_ap_dof=-999;
  my $c_ap_flux=-999;
  my $mdl_file="$data_root/src$src/c_ap.mdl"; # ddchange
  if (-s $mdl_file) {
    my $mdl_header = fits_read_hdr("$mdl_file", "MDL_Models");
    my %mdl = fits_read_bintbl("$mdl_file\[MDL_Models\]");
    my $columns = join(" ",keys(%mdl));
    if ($columns =~ m/parvalue/) {
      $c_ap_nh = $mdl{parvalue}->at(2);
      $c_ap_kt = $mdl{parvalue}->at(4);
      if ($c_ap_kt < 15) {
	$c_ap_kt_flg = 0;
      } else {
	$c_ap_kt_flg = 1;
      }
      $c_ap_kt_norm = $mdl{parvalue}->at(7);
      $c_ap_abund = $mdl{parvalue}->at(5);
    } # if ($columns =~ m/parvalue/) {
    if ($columns =~ m/unc_upper/) {
      $c_ap_nh_err = $mdl{unc_upper}->at(2);
      $c_ap_kt_err = $mdl{unc_upper}->at(4);
      $c_ap_abund_err = $mdl{unc_upper}->at(5);
    } # if ($columns =~ m/unc_upper/) {
    $c_ap_chi = $mdl_header->{F_RSTAT};
    if (($c_ap_chi < 2) && ($c_ap_chi > 0.2)) {
      $c_ap_chi_flg = 0;
    } else {
      $c_ap_chi_flg = 1;
    }
    $c_ap_dof = $mdl_header->{F_DOF};
    $c_ap_flux = $mdl_header->{EFLUX};
    $c_ap_kt_flux = $mdl_header->{EFLUX1};
    #$command="dmlist '".$mdl_file."[MDL_Models]' header | grep flux_rs1";
    #@eflux=`$command`;
    #@eflux_str=split(" ",$eflux[0]);
    #$c_ap_kt_flux = $eflux_str[2];
    $c_ap_flg = $c_ap_kt_flg + $c_ap_chi_flg;
    if ($c_ap_flg != 0) {
      $c_ap_flg = 1;
    }
    
    print OUT "    <MODEL name=\'c_ap\'>\n";
    printf OUT "      <NH>%.2f</NH>\n", $c_ap_nh;
    printf OUT "      <NH_ERR>%.2f</NH_ERR>\n", $c_ap_nh_err;
    printf OUT "      <KT>%.2f</KT>\n", $c_ap_kt;
    printf OUT "      <KT_ERR>%.2f</KT_ERR>\n", $c_ap_kt_err;
    printf OUT "      <KT_FLUX>%.2e</KT_FLUX>\n", $c_ap_kt_flux;
    printf OUT "      <KT_NORM>%.2e</KT_NORM>\n", $c_ap_kt_norm;
    printf OUT "      <KT_FLG>%1d</KT_FLG>\n", $c_ap_kt_flg;
    printf OUT "      <ABUND>%.2f</ABUND>\n", $c_ap_abund;
    printf OUT "      <ABUND_ERR>%.2f</ABUND_ERR>\n", $c_ap_abund_err;
    printf OUT "      <CHI>%.2f</CHI>\n", $c_ap_chi;
    printf OUT "      <CHI_FLG>%1d</CHI_FLG>\n",$c_ap_chi_flg;
    printf OUT "      <DOF>%d</DOF>\n", $c_ap_dof;
    printf OUT "      <FLUX>%.2e</FLUX>\n", $c_ap_flux;
    printf OUT "      <FIT_FLG>%1d</FIT_FLG>\n", $c_ap_flg;
    print OUT "    </MODEL>\n";
  } # if (-s $mdl_file) {

  my $c_ap2_nh=-999;
  my $c_ap2_nh_err=-999;
  my $c_ap2_kt=-999;
  my $c_ap2_kt_err=-999;
  my $c_ap2_abund=-999;
  my $c_ap2_abund_err=-999;
  my $c_ap2_chi=-999;
  my $c_ap2_dof=-999;
  my $c_ap2_flux=-999;
  my $kt_flux=-999;
  my $mdl_file="$data_root/src$src/c_ap2.mdl"; # ddchange
  if (-s $mdl_file) {
    my $mdl_header = fits_read_hdr("$mdl_file", "MDL_Models");
    my %mdl = fits_read_bintbl("$mdl_file\[MDL_Models\]");
    my $columns = join(" ",keys(%mdl));
    if ($columns =~ m/parvalue/) {
      $c_ap2_nh = $mdl{parvalue}->at(2);
      $c_ap2_kt = $mdl{parvalue}->at(4);
      if ($c_ap2_kt < 15) {
	$c_ap2_kt_flg = 0;
      } else {
	$c_ap2_kt_flg = 1;
      }
      $c_ap2_kt_norm = $mdl{parvalue}->at(7);
      $c_ap2_kt2 = $mdl{parvalue}->at(9);
      if ($c_ap2_kt2 < 15) {
	$c_ap2_kt2_flg = 0;
      } else {
	$c_ap2_kt2_flg = 1;
      } 
      $c_ap2_kt2_norm = $mdl{parvalue}->at(12);
      $c_ap2_abund = $mdl{parvalue}->at(5);
    } # if ($columns =~ m/parvalue/) {
    if ($columns =~ m/unc_upper/) {
      $c_ap2_nh_err = $mdl{unc_upper}->at(2);
      $c_ap2_kt_err = $mdl{unc_upper}->at(4);
      $c_ap2_kt2_err = $mdl{unc_upper}->at(9);
      $c_ap2_abund_err = $mdl{unc_upper}->at(5);
    } # if ($columns =~ m/unc_upper/) {
    $c_ap2_chi = $mdl_header->{F_RSTAT};
    if (($c_ap2_chi < 2) && ($c_ap2_chi > 0.2)) {
      $c_ap2_chi_flg = 0;
    } else {
      $c_ap2_chi_flg = 1;
    }
    $c_ap2_dof = $mdl_header->{F_DOF};
    $c_ap2_flux = $mdl_header->{EFLUX};
    $c_ap2_kt1_flux = $mdl_header->{EFLUX1};
    $c_ap2_kt2_flux = $mdl_header->{EFLUX2};
    #$command="dmlist '".$mdl_file."[MDL_Models]' header | grep flux_rs1";
    #@eflux=`$command`;
    #@eflux_str=split(" ",$eflux[0]);
    #$c_ap2_kt1_flux = $eflux_str[2];
    #$command="dmlist '".$mdl_file."[MDL_Models]' header | grep flux_rs2";
    #@eflux=`$command`;
    #@eflux_str=split(" ",$eflux[0]);
    #$c_ap2_kt2_flux = $eflux_str[2];
    $c_ap2_flg = $c_ap2_kt_flg + $c_ap2_kt2_flg + $c_ap2_chi_flg;
    if ($c_ap2_flg != 0) {
      $c_ap2_flg = 1;
    }
    print OUT "    <MODEL name=\'c_ap2\'>\n";
    printf OUT "      <NH>%.2f</NH>\n", $c_ap2_nh;
    printf OUT "      <NH_ERR>%.2f</NH_ERR>\n", $c_ap2_nh_err;
    printf OUT "      <KT>%.2f</KT>\n", $c_ap2_kt;
    printf OUT "      <KT_ERR>%.2f</KT_ERR>\n", $c_ap2_kt_err;
    printf OUT "      <KT_FLUX>%.2e</KT_FLUX>\n", $c_ap2_kt1_flux;
    printf OUT "      <KT_NORM>%.2e</KT_NORM>\n", $c_ap2_kt_norm;
    printf OUT "      <KT_FLG>%1d</KT_FLG>\n", $c_ap2_kt_flg;
    printf OUT "      <KT2>%.2f</KT2>\n", $c_ap2_kt2;
    printf OUT "      <KT2_ERR>%.2f</KT2_ERR>\n", $c_ap2_kt2_err;
    printf OUT "      <KT2_FLUX>%.2e</KT2_FLUX>\n", $c_ap2_kt2_flux;
    printf OUT "      <KT2_NORM>%.2e</KT2_NORM>\n", $c_ap2_kt2_norm;
    printf OUT "      <KT2_FLG>%1d</KT2_FLG>\n", $c_ap2_kt2_flg;
    printf OUT "      <ABUND>%.2f</ABUND>\n", $c_ap2_abund;
    printf OUT "      <ABUND_ERR>%.2f</ABUND_ERR>\n", $c_ap2_abund_err;
    printf OUT "      <CHI>%.2f</CHI>\n", $c_ap2_chi;
    printf OUT "      <CHI_FLG>%1d</CHI_FLG>\n",$c_ap2_chi_flg;
    printf OUT "      <DOF>%d</DOF>\n", $c_ap2_dof;
    printf OUT "      <FLUX>%.2e</FLUX>\n", $c_ap2_flux;
    printf OUT "      <FIT_FLG>%1d</FIT_FLG>\n", $c_ap2_flg;
    print OUT "    </MODEL>\n";
  } # if (-s $mdl_file) {

  my $c_ap2a_nh=-999;
  my $c_ap2a_nh_err=-999;
  my $c_ap2a_kt=-999;
  my $c_ap2a_kt_err=-999;
  my $c_ap2a_kt_flux=-999;
  my $c_ap2a_kt2=-999;
  my $c_ap2a_kt2_err=-999;
  my $c_ap2a_kt2_flux=-999;
  my $c_ap2a_abund=-999;
  my $c_ap2a_abund_err=-999;
  my $c_ap2a_chi=-999;
  my $c_ap2a_dof=-999;
  my $c_ap2a_flux=-999;
  my $mdl_file="$data_root/src$src/c_ap2a.mdl"; # ddchange
  if (-s $mdl_file) {
    $mdl_header = fits_read_hdr("$mdl_file", "MDL_Models");
    %mdl = fits_read_bintbl("$mdl_file\[MDL_Models\]");
    my $columns = join(" ",keys(%mdl));
    if ($columns =~ m/parvalue/) {
      $c_ap2a_nh = $mdl{parvalue}->at(2);
      $c_ap2a_kt = $mdl{parvalue}->at(4);
      if ($c_ap2a_kt < 15) {
	$c_ap2a_kt_flg = 0;
      } else {
	$c_ap2a_kt_flg = 1;
      } 
      $c_ap2a_kt_norm = $mdl{parvalue}->at(7);
      $c_ap2a_kt2 = $mdl{parvalue}->at(9);
            if ($c_ap2a_kt2 < 15) {
	$c_ap2a_kt2_flg = 0;
      } else {
	$c_ap2a_kt2_flg = 1;
      } 
      $c_ap2a_kt2_norm = $mdl{parvalue}->at(12);
      $c_ap2a_abund = $mdl{parvalue}->at(5);
    } # if ($columns =~ m/parvalue/) {
    if ($columns =~ m/unc_upper/) {
      $c_ap2a_nh_err = $mdl{unc_upper}->at(2);
      $c_ap2a_kt_err = $mdl{unc_upper}->at(4);
      $c_ap2a_kt2_err = $mdl{unc_upper}->at(9);
      $c_ap2a_abund_err = $mdl{unc_upper}->at(5);
    } # if ($columns =~ m/unc_upper/) {
    $c_ap2a_chi = $mdl_header->{F_RSTAT};
    if (($c_ap2a_chi < 2) && ($c_ap2_chi > 0.2)) {
      $c_ap2a_chi_flg = 0;
    } else {
      $c_ap2a_chi_flg = 1;
    }
    $c_ap2a_dof = $mdl_header->{F_DOF};
    $c_ap2a_flux = $mdl_header->{EFLUX};
    $c_ap2a_kt1_flux = $mdl_header->{EFLUX1};
    $c_ap2a_kt2_flux = $mdl_header->{EFLUX2};
    #$command="dmlist '".$mdl_file."[MDL_Models]' header | grep flux_rs1";
    #@eflux=`$command`;
    #@eflux_str=split(" ",$eflux[0]);
    #$c_ap2a_kt1_flux = $eflux_str[2];
    #$command="dmlist '".$mdl_file."[MDL_Models]' header | grep flux_rs2";
    #@eflux=`$command`;
    #@eflux_str=split(" ",$eflux[0]);
    #$c_ap2a_kt2_flux = $eflux_str[2];
    $c_ap2a_flg = $c_ap2a_kt_flg + $c_ap2a_kt2_flg + $c_ap2a_chi_flg;
    if ($c_ap2a_flg != 0) {
      $c_ap2a_flg = 1;
    }
    print OUT "    <MODEL name=\'c_ap2a\'>\n";
    printf OUT "      <NH>%.2f</NH>\n", $c_ap2a_nh;
    printf OUT "      <NH_ERR>%.2f</NH_ERR>\n", $c_ap2a_nh_err;
    printf OUT "      <KT>%.2f</KT>\n", $c_ap2a_kt;
    printf OUT "      <KT_ERR>%.2f</KT_ERR>\n", $c_ap2a_kt_err;
    printf OUT "      <KT_FLUX>%.2e</KT_FLUX>\n", $c_ap2a_kt1_flux;
    printf OUT "      <KT_NORM>%.2e</KT_NORM>\n", $c_ap2a_kt_norm;
    printf OUT "      <KT_FLG>%1d</KT_FLG>\n", $c_ap2a_kt_flg;
    printf OUT "      <KT2>%.2f</KT2>\n", $c_ap2a_kt2;
    printf OUT "      <KT2_ERR>%.2f</KT2_ERR>\n", $c_ap2a_kt2_err;
    printf OUT "      <KT2_FLUX>%.2e</KT2_FLUX>\n", $c_ap2a_kt2_flux;
    printf OUT "      <KT2_NORM>%.2e</KT2_NORM>\n", $c_ap2a_kt2_norm;
    printf OUT "      <KT2_FLG>%1d</KT2_FLG>\n", $c_ap2a_kt2_flg;
    printf OUT "      <ABUND>%.2f</ABUND>\n", $c_ap2a_abund;
    printf OUT "      <ABUND_ERR>%.2f</ABUND_ERR>\n", $c_ap2a_abund_err;
    printf OUT "      <CHI>%.2f</CHI>\n", $c_ap2a_chi;
    printf OUT "      <CHI_FLG>%1d</CHI_FLG>\n",$c_ap2a_chi_flg;
    printf OUT "      <DOF>%d</DOF>\n", $c_ap2a_dof;
    printf OUT "      <FLUX>%.2e</FLUX>\n", $c_ap2a_flux;
    printf OUT "      <FIT_FLG>%1d</FIT_FLG>\n", $c_ap2a_flg;
    print OUT "    </MODEL>\n";
  } # if (-s $mdl_file) {

  my $c_mk_nh=-999;
  my $c_mk_nh_err=-999;
  my $c_mk_kt=-999;
  my $c_mk_kt_err=-999;
  my $c_mk_kt_flux=-999;
  my $c_mk_abund=-999;
  my $c_mk_abund_err=-999;
  my $c_mk_chi=-999;
  my $c_mk_dof=-999;
  my $c_mk_flux=-999;
  my $mdl_file="$data_root/src$src/c_mk.mdl"; # ddchange
  if (-s $mdl_file) {
    my $mdl_header = fits_read_hdr("$mdl_file", "MDL_Models");
    my %mdl = fits_read_bintbl("$mdl_file\[MDL_Models\]");
    my $columns = join(" ",keys(%mdl));
    if ($columns =~ m/parvalue/) {
      $c_mk_nh = $mdl{parvalue}->at(2);
      $c_mk_kt = $mdl{parvalue}->at(4);
      if ($c_mk_kt < 15) {
	$c_mk_kt_flg = 0;
      } else {
	$c_mk_kt_flg = 1;
      }
      $c_mk_kt_norm = $mdl{parvalue}->at(7);
      $c_mk_abund = $mdl{parvalue}->at(5);
    } # if ($columns =~ m/parvalue/) {
    if ($columns =~ m/unc_upper/) {
      $c_mk_nh_err = $mdl{unc_upper}->at(2);
      $c_mk_kt_err = $mdl{unc_upper}->at(4);
      $c_mk_abund_err = $mdl{unc_upper}->at(5);
    } # if ($columns =~ m/unc_upper/) {
    $c_mk_chi = $mdl_header->{F_RSTAT};
    if (($c_mk_chi < 2) && ($c_ap_chi > 0.2)) {
      $c_mk_chi_flg = 0;
    } else {
      $c_mk_chi_flg = 1;
    }
    $c_mk_dof = $mdl_header->{F_DOF};
    $c_mk_flux = $mdl_header->{EFLUX};
    $c_mk_kt_flux = $mdl_header->{EFLUX1};
    #$command="dmlist '".$mdl_file."[MDL_Models]' header | grep flux_rs1";
    #@eflux=`$command`;
    #@eflux_str=split(" ",$eflux[0]);
    #$c_mk_kt_flux = $eflux_str[2];
    $c_mk_flg = $c_ap_kt_flg + $c_ap_chi_flg;
    if ($c_mk_flg != 0) {
      $c_mk_flg = 1;
    }
    
    print OUT "    <MODEL name=\'c_mk\'>\n";
    printf OUT "      <NH>%.2f</NH>\n", $c_mk_nh;
    printf OUT "      <NH_ERR>%.2f</NH_ERR>\n", $c_mk_nh_err;
    printf OUT "      <KT>%.2f</KT>\n", $c_mk_kt;
    printf OUT "      <KT_ERR>%.2f</KT_ERR>\n", $c_mk_kt_err;
    printf OUT "      <KT_FLUX>%.2e</KT_FLUX>\n", $c_mk_kt_flux;
    printf OUT "      <KT_NORM>%.2e</KT_NORM>\n", $c_mk_kt_norm;
    printf OUT "      <KT_FLG>%1d</KT_FLG>\n", $c_mk_kt_flg;
    printf OUT "      <ABUND>%.2f</ABUND>\n", $c_mk_abund;
    printf OUT "      <ABUND_ERR>%.2f</ABUND_ERR>\n", $c_mk_abund_err;
    printf OUT "      <CHI>%.2f</CHI>\n", $c_mk_chi;
    printf OUT "      <CHI_FLG>%1d</CHI_FLG>\n",$c_mk_chi_flg;
    printf OUT "      <DOF>%d</DOF>\n", $c_mk_dof;
    printf OUT "      <FLUX>%.2e</FLUX>\n", $c_mk_flux;
    printf OUT "      <FIT_FLG>%1d</FIT_FLG>\n", $c_mk_flg;
    print OUT "    </MODEL>\n";
  } # if (-s $mdl_file) {

  my $c_mk2_nh=-999;
  my $c_mk2_nh_err=-999;
  my $c_mk2_kt=-999;
  my $c_mk2_kt_err=-999;
  my $c_mk2_abund=-999;
  my $c_mk2_abund_err=-999;
  my $c_mk2_chi=-999;
  my $c_mk2_dof=-999;
  my $c_mk2_flux=-999;
  my $kt_flux=-999;
  my $mdl_file="$data_root/src$src/c_mk2.mdl"; # ddchange
  if (-s $mdl_file) {
    my $mdl_header = fits_read_hdr("$mdl_file", "MDL_Models");
    my %mdl = fits_read_bintbl("$mdl_file\[MDL_Models\]");
    my $columns = join(" ",keys(%mdl));
    if ($columns =~ m/parvalue/) {
      $c_mk2_nh = $mdl{parvalue}->at(2);
      $c_mk2_kt = $mdl{parvalue}->at(4);
      if ($c_mk2_kt < 15) {
	$c_mk2_kt_flg = 0;
      } else {
	$c_mk2_kt_flg = 1;
      }
      $c_mk2_kt_norm = $mdl{parvalue}->at(7);
      $c_mk2_kt2 = $mdl{parvalue}->at(9);
      if ($c_mk2_kt2 < 15) {
	$c_mk2_kt2_flg = 0;
      } else {
	$c_mk2_kt2_flg = 1;
      } 
      $c_mk2_kt2_norm = $mdl{parvalue}->at(12);
      $c_mk2_abund = $mdl{parvalue}->at(5);
    } # if ($columns =~ m/parvalue/) {
    if ($columns =~ m/unc_upper/) {
      $c_mk2_nh_err = $mdl{unc_upper}->at(2);
      $c_mk2_kt_err = $mdl{unc_upper}->at(4);
      $c_mk2_kt2_err = $mdl{unc_upper}->at(9);
      $c_mk2_abund_err = $mdl{unc_upper}->at(5);
    } # if ($columns =~ m/unc_upper/) {
    $c_mk2_chi = $mdl_header->{F_RSTAT};
    if (($c_mk2_chi < 2) && ($c_ap2_chi > 0.2)) {
      $c_mk2_chi_flg = 0;
    } else {
      $c_mk2_chi_flg = 1;
    }
    $c_mk2_dof = $mdl_header->{F_DOF};
    $c_mk2_flux = $mdl_header->{EFLUX};
    $c_mk2_kt1_flux = $mdl_header->{EFLUX1};
    $c_mk2_kt2_flux = $mdl_header->{EFLUX2};
    #$command="dmlist '".$mdl_file."[MDL_Models]' header | grep flux_rs1";
    #@eflux=`$command`;
    #@eflux_str=split(" ",$eflux[0]);
    #$c_mk2_kt1_flux = $eflux_str[2];
    #$command="dmlist '".$mdl_file."[MDL_Models]' header | grep flux_rs2";
    #@eflux=`$command`;
    #@eflux_str=split(" ",$eflux[0]);
    #$c_mk2_kt2_flux = $eflux_str[2];
    $c_mk2_flg = $c_ap2_kt_flg + $c_ap2_kt2_flg + $c_ap2_chi_flg;
    if ($c_mk2_flg != 0) {
      $c_mk2_flg = 1;
    }
    print OUT "    <MODEL name=\'c_mk2\'>\n";
    printf OUT "      <NH>%.2f</NH>\n", $c_mk2_nh;
    printf OUT "      <NH_ERR>%.2f</NH_ERR>\n", $c_mk2_nh_err;
    printf OUT "      <KT>%.2f</KT>\n", $c_mk2_kt;
    printf OUT "      <KT_ERR>%.2f</KT_ERR>\n", $c_mk2_kt_err;
    printf OUT "      <KT_FLUX>%.2e</KT_FLUX>\n", $c_mk2_kt1_flux;
    printf OUT "      <KT_NORM>%.2e</KT_NORM>\n", $c_mk2_kt_norm;
    printf OUT "      <KT_FLG>%1d</KT_FLG>\n", $c_mk2_kt_flg;
    printf OUT "      <KT2>%.2f</KT2>\n", $c_mk2_kt2;
    printf OUT "      <KT2_ERR>%.2f</KT2_ERR>\n", $c_mk2_kt2_err;
    printf OUT "      <KT2_FLUX>%.2e</KT2_FLUX>\n", $c_mk2_kt2_flux;
    printf OUT "      <KT2_NORM>%.2e</KT2_NORM>\n", $c_mk2_kt2_norm;
    printf OUT "      <KT2_FLG>%1d</KT2_FLG>\n", $c_mk2_kt2_flg;
    printf OUT "      <ABUND>%.2f</ABUND>\n", $c_mk2_abund;
    printf OUT "      <ABUND_ERR>%.2f</ABUND_ERR>\n", $c_mk2_abund_err;
    printf OUT "      <CHI>%.2f</CHI>\n", $c_mk2_chi;
    printf OUT "      <CHI_FLG>%1d</CHI_FLG>\n",$c_mk2_chi_flg;
    printf OUT "      <DOF>%d</DOF>\n", $c_mk2_dof;
    printf OUT "      <FLUX>%.2e</FLUX>\n", $c_mk2_flux;
    printf OUT "      <FIT_FLG>%1d</FIT_FLG>\n", $c_mk2_flg;
    print OUT "    </MODEL>\n";
  } # if (-s $mdl_file) {

  my $c_mk2a_nh=-999;
  my $c_mk2a_nh_err=-999;
  my $c_mk2a_kt=-999;
  my $c_mk2a_kt_err=-999;
  my $c_mk2a_kt_flux=-999;
  my $c_mk2a_kt2=-999;
  my $c_mk2a_kt2_err=-999;
  my $c_mk2a_kt2_flux=-999;
  my $c_mk2a_abund=-999;
  my $c_mk2a_abund_err=-999;
  my $c_mk2a_chi=-999;
  my $c_mk2a_dof=-999;
  my $c_mk2a_flux=-999;
  my $mdl_file="$data_root/src$src/c_mk2a.mdl"; # ddchange
  if (-s $mdl_file) {
    $mdl_header = fits_read_hdr("$mdl_file", "MDL_Models");
    %mdl = fits_read_bintbl("$mdl_file\[MDL_Models\]");
    my $columns = join(" ",keys(%mdl));
    if ($columns =~ m/parvalue/) {
      $c_mk2a_nh = $mdl{parvalue}->at(2);
      $c_mk2a_kt = $mdl{parvalue}->at(4);
      if ($c_mk2a_kt < 15) {
	$c_mk2a_kt_flg = 0;
      } else {
	$c_mk2a_kt_flg = 1;
      } 
      $c_mk2a_kt_norm = $mdl{parvalue}->at(7);
      $c_mk2a_kt2 = $mdl{parvalue}->at(9);
            if ($c_mk2a_kt2 < 15) {
	$c_mk2a_kt2_flg = 0;
      } else {
	$c_mk2a_kt2_flg = 1;
      } 
      $c_mk2a_kt2_norm = $mdl{parvalue}->at(12);
      $c_mk2a_abund = $mdl{parvalue}->at(5);
    } # if ($columns =~ m/parvalue/) {
    if ($columns =~ m/unc_upper/) {
      $c_mk2a_nh_err = $mdl{unc_upper}->at(2);
      $c_mk2a_kt_err = $mdl{unc_upper}->at(4);
      $c_mk2a_kt2_err = $mdl{unc_upper}->at(9);
      $c_mk2a_abund_err = $mdl{unc_upper}->at(5);
    } # if ($columns =~ m/unc_upper/) {
    $c_mk2a_chi = $mdl_header->{F_RSTAT};
    if (($c_mk2a_chi < 2) && ($c_ap2_chi > 0.2)) {
      $c_mk2a_chi_flg = 0;
    } else {
      $c_mk2a_chi_flg = 1;
    }
    $c_mk2a_dof = $mdl_header->{F_DOF};
    $c_mk2a_flux = $mdl_header->{EFLUX};
    $c_mk2a_kt1_flux = $mdl_header->{EFLUX1};
    $c_mk2a_kt2_flux = $mdl_header->{EFLUX2};
    #$command="dmlist '".$mdl_file."[MDL_Models]' header | grep flux_rs1";
    #@eflux=`$command`;
    #@eflux_str=split(" ",$eflux[0]);
    #$c_mk2a_kt1_flux = $eflux_str[2];
    #$command="dmlist '".$mdl_file."[MDL_Models]' header | grep flux_rs2";
    #@eflux=`$command`;
    #@eflux_str=split(" ",$eflux[0]);
    #$c_mk2a_kt2_flux = $eflux_str[2];
    $c_mk2a_flg = $c_ap2a_kt_flg + $c_ap2a_kt2_flg + $c_ap2a_chi_flg;
    if ($c_mk2a_flg != 0) {
      $c_mk2a_flg = 1;
    }
    print OUT "    <MODEL name=\'c_mk2a\'>\n";
    printf OUT "      <NH>%.2f</NH>\n", $c_mk2a_nh;
    printf OUT "      <NH_ERR>%.2f</NH_ERR>\n", $c_mk2a_nh_err;
    printf OUT "      <KT>%.2f</KT>\n", $c_mk2a_kt;
    printf OUT "      <KT_ERR>%.2f</KT_ERR>\n", $c_mk2a_kt_err;
    printf OUT "      <KT_FLUX>%.2e</KT_FLUX>\n", $c_mk2a_kt1_flux;
    printf OUT "      <KT_NORM>%.2e</KT_NORM>\n", $c_mk2a_kt_norm;
    printf OUT "      <KT_FLG>%1d</KT_FLG>\n", $c_mk2a_kt_flg;
    printf OUT "      <KT2>%.2f</KT2>\n", $c_mk2a_kt2;
    printf OUT "      <KT2_ERR>%.2f</KT2_ERR>\n", $c_mk2a_kt2_err;
    printf OUT "      <KT2_FLUX>%.2e</KT2_FLUX>\n", $c_mk2a_kt2_flux;
    printf OUT "      <KT2_NORM>%.2e</KT2_NORM>\n", $c_mk2a_kt2_norm;
    printf OUT "      <KT2_FLG>%1d</KT2_FLG>\n", $c_mk2a_kt2_flg;
    printf OUT "      <ABUND>%.2f</ABUND>\n", $c_mk2a_abund;
    printf OUT "      <ABUND_ERR>%.2f</ABUND_ERR>\n", $c_mk2a_abund_err;
    printf OUT "      <CHI>%.2f</CHI>\n", $c_mk2a_chi;
    printf OUT "      <CHI_FLG>%1d</CHI_FLG>\n",$c_mk2a_chi_flg;
    printf OUT "      <DOF>%d</DOF>\n", $c_mk2a_dof;
    printf OUT "      <FLUX>%.2e</FLUX>\n", $c_mk2a_flux;
    printf OUT "      <FIT_FLG>%1d</FIT_FLG>\n", $c_mk2a_flg;
    print OUT "    </MODEL>\n";
  } # if (-s $mdl_file) {

  my $cstat_nh=-999;
  my $cstat_nh_err=-999;
  my $cstat_kt=-999;
  my $cstat_kt_err=-999;
  my $cstat_kt_flux=-999;
  my $cstat_abund=-999;
  my $cstat_abund_err=-999;
  my $cstat_chi=-999;
  my $cstat_dof=-999;
  my $cstat_flux=-999;
  my $mdl_file="$data_root/src$src/cstat.mdl"; # ddchange
  if (-s $mdl_file) {
    $mdl_header = fits_read_hdr("$mdl_file", "MDL_Models");
    %mdl = fits_read_bintbl("$mdl_file\[MDL_Models\]");
    my $columns = join(" ",keys(%mdl));
    if ($columns =~ m/parvalue/) {
      $cstat_nh = $mdl{parvalue}->at(2);
      $cstat_kt = $mdl{parvalue}->at(4);
      if ($cstat_kt < 15) {
	$cstat_kt_flg = 0;
      } else {
	$cstat_kt_flg = 1;
      }
      $cstat_kt_norm = $mdl{parvalue}->at(7);
      $cstat_abund = $mdl{parvalue}->at(5);
    } # if ($columns =~ m/parvalue/) {
    if ($columns =~ m/unc_upper/) {
      $cstat_nh_err = $mdl{unc_upper}->at(2);
      $cstat_kt_err = $mdl{unc_upper}->at(4);
      $cstat_abund_err = $mdl{unc_upper}->at(5);
    } # if ($columns =~ m/unc_upper/) {
    $cstat_chi = $mdl_header->{F_RSTAT};
    if (($cstat_chi < 2) && ($cstat_chi > 0.2)) {
      $cstat_chi_flg = 0;
    } else {
      $cstat_chi_flg = 1;
    }
    $cstat_dof = $mdl_header->{F_DOF};
    $cstat_flux = $mdl_header->{EFLUX};
    $cstat_kt1_flux = $mdl_header->{EFLUX1};
    $cstat_kt2_flux = $mdl_header->{EFLUX2};
    #$command="dmlist '".$mdl_file."[MDL_Models]' header | grep flux_rs1";
    #@eflux=`$command`;
    #@eflux_str=split(" ",$eflux[0]);
    #$cstat_kt1_flux = $eflux_str[2];
    $cstat_flg = $cstat_kt_flg + $cstat_kt2_flg + $cstat_chi_flg;
    if ($cstat_flg != 0) {
      $cstat_flg = 1;
    }
    print OUT "    <MODEL name=\'cstat\'>\n";
    printf OUT "      <NH>%.2f</NH>\n", $cstat_nh;
    printf OUT "      <NH_ERR>%.2f</NH_ERR>\n", $cstat_nh_err;
    printf OUT "      <KT>%.2f</KT>\n", $cstat_kt;
    printf OUT "      <KT_ERR>%.2f</KT_ERR>\n", $cstat_kt_err;
    printf OUT "      <KT_FLUX>%.2e</KT_FLUX>\n", $cstat_kt1_flux;
    printf OUT "      <KT_NORM>%.2e</KT_NORM>\n", $cstat_kt_norm;
    printf OUT "      <KT_FLG>%1d</KT_FLG>\n", $cstat_kt_flg;
    printf OUT "      <ABUND>%.2f</ABUND>\n", $cstat_abund;
    printf OUT "      <ABUND_ERR>%.2f</ABUND_ERR>\n", $cstat_abund_err;
    printf OUT "      <CHI>%.2f</CHI>\n", $cstat_chi;
    printf OUT "      <CHI_FLG>%1d</CHI_FLG>\n",$cstat_chi_flg;
    printf OUT "      <DOF>%d</DOF>\n", $cstat_dof;
    printf OUT "      <FLUX>%.2e</FLUX>\n", $cstat_flux;
    printf OUT "      <FIT_FLG>%1d</FIT_FLG>\n", $cstat_flg;
    print OUT "    </MODEL>\n";
  } # if (-s $mdl_file) {
  print OUT "  </SPECTRA>\n";

  ## BBLOCKS
  my $dat="$data_root/src$src/bblocks.dat"; # ddchange
  open(DAT,"<$dat");
  $line=<DAT>;
  chomp $line;
  @data=split(/\s+/,$line);
  $bbnum=1;
  $lastn=$data[1];
  @levels=$data[4]*1000.;
  @levels_err=$data[5]*1000.;
  @dt=$data[3]-$data[2];
  while ($line=<DAT>) {
    chomp $line;
    @data=split(/\s+/,$line);
    if ($data[0] eq "Change") {last;}
    if ($data[3]-$data[2] > 300) {
    #if ($data[1]-$lastn > 3) {
      #print "$lastn\n";  #debug
      push(@levels,$data[4]*1000.);
      push(@levels_err,$data[5]*1000.);
      push(@dt,$data[3]-$data[2]);
      $bbnum++;
    } # if ($data[1]-$lastn > 3) {
    #else { print "skipped $ii\n"; }
    $lastn=$data[1];
  } # while ($line=<DAT>) {
  close DAT;
  # calculate max derivative
  $max_deriv=0;
  for ($ideriv=1;$ideriv<=$#levels;$ideriv++) {
    if ($dt[$ideriv] lt 1) {$dt[$ideriv]=1;}
    $deriv=abs($levels[$ideriv]-$levels[$ideriv-1])/$dt[$ideriv-1];
    if ($deriv > $max_deriv) {$max_deriv=$deriv;}
    $deriv=abs($levels[$ideriv]-$levels[$ideriv-1])/$dt[$ideriv];
    if ($deriv > $max_deriv) {$max_deriv=$deriv;}
  } # for ($ideriv=1;$ideriv<=$#levels;$ideriv++) {

  #print OUT "  <FLARE_FLAG>";
  #if ($max_deriv >= 10) {
  #  print OUT "$max_deriv";
  #} else {
  #  print OUT "0";
  #} # if ($max_deriv >= 10) {
  #print OUT "  </FLARE_FLAG>\n";
  print OUT "  <BBLOCKS>\n";
  print OUT "    <BBLOCKS_SIG sig=\"$bbsig\">\n";
  $lcl_pflg = 0;
  for ($ibblocks=0;$ibblocks<=$#levels;$ibblocks++) {
    if (($levels[$ibblocks]/1000. < 0.01) && ($lcl_pflg == 0)) {
      $lcl_pflg = 0;
    } elsif (($levels[$ibblocks]/1000. < 0.05) && ($levels[$ibblocks]/1000. >= 0.01) && ($lcl_pflg <=1)) {
      $lcl_pflg = 1;
    } elsif (($levels[$ibblocks]/1000. >= 0.05) && ($lcl_pflg <=2)) {
      $lcl_pflg = 2;
    }
    print OUT "      <BBLOCKS_N n=\"$ibblocks\">\n";
    printf OUT "        <BBLOCKS_RATE>%.3f</BBLOCKS_RATE>\n", $levels[$ibblocks];
    printf OUT "        <BBLOCKS_ERR>%.3f</BBLOCKS_ERR>\n", $levels_err[$ibblocks];
    printf OUT "        <BBLOCKS_DT>%d</BBLOCKS_DT>\n", $dt[$ibblocks];
    print OUT "      </BBLOCKS_N>\n";
  } # for ($ibblocks=0;$ibblocks<=$#levels;$ibblocks++) {
  print OUT "    </BBLOCKS_SIG>\n";
  print OUT "  </BBLOCKS>\n";
  printf OUT "   <GP_FLAG>%1d</GP_FLAG>\n",$gbl_pflg;
  printf OUT "   <BBLOCKS_PFLG>%1d</BBLOCKS_PFLG>\n", $lcl_pflg;

  ## GLvary
  my $dat="$data_root/src$src/GLvary.out";
  $gl_odds=999;
  $gl_prob=999;
  $gl_indx=999;
  open(DAT,"<$dat");
  while ($line=<DAT>) {
    if ($line =~ m/Odds for variable signal/) {
      chomp $line;
      @data=split(/\s+/,$line);
      $gl_odds=$data[$#data];
    }
    if ($line =~ m/Probability of a variable signal/) {
      chomp $line;
      @data=split(/\s+/,$line);
      $gl_prob=$data[$#data];
    }
    if ($line =~ m/Variability index/) {
      chomp $line;
      @data=split(/\s+/,$line);
      $gl_indx=$data[$#data];
    }
  } # while ($line=<DAT>) {
  print OUT "  <GLVARY>\n";
  printf OUT "    <GLVARY_ODDS>%.3f</GLVARY_ODDS>\n",$gl_odds;
  printf OUT "    <GLVARY_PROB>%.3f</GLVARY_PROB>\n",$gl_prob;
  printf OUT "    <GLVARY_INDEX>%2d</GLVARY_INDEX>\n",$gl_indx;
  print OUT "  </GLVARY>\n";
  print OUT "</SOURCE>\n";
  $date=`date`;
  chomp $date;
  print OUT "<created>$date</created>\n";
  print OUT "</root>\n";
  close OUT;
  # write IR matches
  $irdatfile="$data_root/src$src/tmc.match";
  if (-s $irdatfile) { 
    open (INIR,"<$data_root/src$src/tmc.match");
    $outfile="$data_root/src$src/src$src\_2mass.xml";
    open(OUT,">$outfile");
    print OUT "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\n";
    print OUT "<?xml-stylesheet type=\"text/xsl\" href=\"..\/..\/anc_src.xsl\"?>\n";
    print OUT "<root>\n";
    print OUT "<SOURCE id=\"$src\">\n";
    print OUT "  <ID>$src</ID>\n";
    printf OUT "  <RA str=\"$ra_str\">%10.5f</RA>\n",$ra;
    printf OUT "  <DEC str=\"$dec_str\">%10.5f</DEC>\n",$dec;
    $irline=<INIR>;
    chomp $irline;
    $irline=~s/^\s+//;
    @irhead=split(/\s+/,$irline);
    $irline=<INIR>;
    chomp $irline;
    $irline=~s/^\s+//;  #sometimes there are blanks in front
    @irdata=split(/\s+/,$irline);
    for ($iir=0;$iir<=$#irhead;$iir++) {
      print OUT "<$irhead[$iir]>$irdata[$iir]</$irhead[$iir]>\n";
    } # for ($iir=0;$iir<=$#irhead;$iir++) {
    print OUT "</SOURCE>\n";
    print OUT "</root>\n";
    close OUT;
  } # if (-s $irdatfile) { 

} # while ($inline=<IN>) {
close IN;
#
