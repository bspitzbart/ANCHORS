#!/usr/bin/env /proj/axaf/bin/perl
##!/opt/local/bin/perl
# collect nH,kT,abund,chi^2, etc. from YAXX fits
# $ARGV[0] is name of file which contains list of source numbers and
# RA,Dec to process
#  read (src.txt) (same as AE input file)
# $ARGV[1] is output filename

@models=qw(a31);
$data_root="/data/ANCHORS/YAXX/05407/Data/obs5407";
$html_root="./";
$bbsig="95.02";  # bblocks significance

#use lib '/proj/sot/ska/lib/site_perl/MST_pkgs/';
use coords;
use Astro::FITS::Header::CFITSIO;
use CFITSIO::Simple;

$tar_file="/data/ANCHORS/chandra_clusters.txt";

if ($#ARGV != 2) {
  die "Usage:\n  $0 <infile> <outfile> <obsid>\n";
}
open(IN,"<$ARGV[0]") || die "Input file $ARGV[0] not found.\n";
if (-s $ARGV[1]) {
  die "Cannot overwrite $ARGV[1].\n";
} else {
  open(OUT,">$ARGV[1]");
} # if (! -s $ARGV[1]) {


#****** read target data ****
open(TAR,"<$tar_file") || die "Cannot read $tar_file\n";
$found=0;
while ($inline=<TAR>) {
  chomp $inline;
  @line=split(/\t/,$inline);
  if ($line[1] == $ARGV[2]) {
    $found=1;
    $tar_seq=$line[0];
    $tar_obs=$line[1];
    $tar_ins=$line[2];
    $tar_exp=$line[5];
    $tar_nam=$line[6];
    $tar_ra=$line[10];
    $tar_dec=$line[11];
    $tar_tstart=$line[13];
    # change format on some
    $tar_ra=~s/ /:/g;
    $tar_dec=~s/ /:/g;
    @td=split(/ /,$tar_tstart);
    $tar_date=$td[0];
    last;
  } # if ($line[1] == $ARGV[2]) {
} #while ($inline=<TAR>) {
if ($found == 0) { die "Obsid $ARGV[2] not found in $tar_file.\n";}

print OUT "  $tar_obs\n";
print OUT "  $tar_nam\n";
print OUT "  $tar_tstart\n";
print OUT "  $tar_exp\n";
print OUT "  $tar_seq\n";
print OUT "  $tar_ins\n";
print OUT "  $tar_date\n";
print OUT "  $tar_ra,$tar_dec\n";
###### Full Title:
#  printf OUT "src\tRA\tDEC\tRA[deg]\tDEC[deg]\tcounts\tquant1\tquant2\tquant3\tquant4\tquant5\tquant6\ta31:nh\tnh_err\tkT\tkT_err\tkT_flux\tkT_norm\tchi\tdof\ttot_flux\tbbap:nH\tnH_err\tkT\tkT_err\tkT_flux\tnorm\tchi\tdof\ttot_flux\tbbap2:nH\tnH_err\tkT\tkT_err\tkT_flux\tkT_norm\tkT2\tkT2_err\tkT2_flux\tkT2_norm\tchi\tdof\ttot_flux\tBB.sig\tiBBlocks\tlvls\tlvls_err\tdt\n";

###### Uncomment for Table1 header:
 printf OUT "src\tRA\tDEC\tRA\tDEC\tcounts\t0.25\%\t25p_err\t0.50\%\t50p_err\t0.75\%\t75p_err\ta31:nh\tnh_err\tkT\tkT_err\tkT_flux\tkT_norm\tchi\tdof\ttot_flux\tbbap:nH\tnH_err\tkT\tkT_err\tkT_flux\tnorm\tchi\tdof\ttot_flux\t\n";
  printf OUT "num\t[h:m:s]\t[h:m:s]\t[deg]\t[deg]\t \t[keV]\t[keV]\t[keV]\t[keV]\t[keV]\t[keV]\t[10^22\/cm^2]\t[10^22\/cm^2]\t[keV]\t[keV]\t[ergs\/cm^2\/s]\t \t[chi^2\/deg. of freedom]\t[num]\t[ergs\/cm^2\/s]\t[10^22\/cm^2]\t[10^22\/cm^2]\t[keV]\t[keV]\t[ergs\/cm^2\/s]\t \t[chi^2\/deg. of freedom]\t[num]\t[ergs\/cm^2\/s]\t\n";

####### Uncomment for Table2 header:
#printf OUT "src\tbbap2:nH\tnH_err\tkT\tkT_err\tkT_flux\tkT_norm\tkT2\tkT2_err\tkT2_flux\tkT2_norm\tchi\tdof\ttot_flux\tBB.sig\tiBBlocks\tlevel\tlvls_err\tdt\n";
#printf OUT "num\t[10^22\/cm^2]\t[10^22\/cm^2]\t[keV]\t[keV]\t[ergs\/cm^2\/s]\t \t[keV]\t[keV]\t[ergs\/cm^2\/s]\t \t[chi^2\/deg. of freedom]\t[num]\t \t[num]\t[cts\/ksec]\t[cts\/ksec]\t[sec]\n";

###### Uncomment for small Table 3 addition:
#printf OUT "src\tRA\tDEC\tRA\tDEC\tcounts\ttot_flux\n";
#printf OUT "num\t[h:m:s]\t[h:m:s]\t[deg]\t[deg]\t \t[ergs\/cm^2\/s]\n";

while ($inline=<IN>) {
  chomp $inline;
  @line=split(/\s+/,$inline);
  $src=$line[0];
  $ra=$line[1];
  $dec=$line[2];
  ($ra_str,$dec_str)=&dec2seg($ra,$dec);
  my $cnts=-999;
  $mdl_file="/data/ANCHORS/YAXX/05407/Data/obs5407/src$src/a31.mdl"; #ddchange
  if (-s $mdl_file) {
    my $mdl_header = fits_read_hdr("$mdl_file", "MDL_Models");
    my %mdl = fits_read_bintbl("$mdl_file\[MDL_Models\]");
    @cnts=$mdl_header->{"COUNTS"};
    $cnts=$cnts[0];
  } #if (-s $mdl_file) {
  if ($cnts <= 0) {
    $mdl_file="/data/ANCHORS/YAXX/05407/Data/obs5407/src$src/bbap.mdl"; #ddchange
    if (-s $mdl_file) {
      my $mdl_header = fits_read_hdr("$mdl_file", "MDL_Models");
      my %mdl = fits_read_bintbl("$mdl_file\[MDL_Models\]");
      @cnts=$mdl_header->{"COUNTS"};
      $cnts=$cnts[0];
    } #if (-s $mdl_file) {
  } #if ($cnts <= 0) {
  if ($cnts <= 0) {
    $mdl_file="/data/ANCHORS/YAXX/05407/Data/obs5407/src$src/bbap2.mdl"; #ddchange
    if (-s $mdl_file) {
      my $mdl_header = fits_read_hdr("$mdl_file", "MDL_Models");
      my %mdl = fits_read_bintbl("$mdl_file\[MDL_Models\]");
      @cnts=$mdl_header->{"COUNTS"};
      $cnts=$cnts[0];
    } #if (-s $mdl_file) {
  } #if ($cnts <= 0) {

###### uncomment for table1 or table3:
 printf OUT "%3d\t%12s\t%12s\t%12.8f\t%12.8f\t%8.1f\t", $src, $ra_str, $dec_str, $ra, $dec, $cnts; 
###### uncomment for table2
#      printf OUT "%3d\t", $src;

  my $quant_file="/data/ANCHORS/YAXX/05407/Data/obs5407/src$src/quantile.dat"; # ddchange
  open (QUANT,"<$quant_file");
  $qinline=<QUANT>; # skip first line
  $qinline=<QUANT>;
  chomp $qinline;
  @qline=split(/\s+/,$qinline);
###### uncomment for table1
  printf OUT "%7.4f\t%7.4f\t%7.4f\t%7.4f\t%7.4f\t%7.4f\t", $qline[1],$qline[2],$qline[3],$qline[4],$qline[5],$qline[6];

    my $a31_nh=-999;
    my $a31_nh_err=-999;
    my $a31_kt=-999;
    my $a31_kt_err=-999;
    my $a31_kt_flux=-999;
    my $a31_abund=-999;
    my $a31_abund_err=-999;
    my $a31_chi=-999;
    my $a31_dof=-999;
    my $a31_flux=-999;
    my $mdl_file="/data/ANCHORS/YAXX/05407/Data/obs5407/src$src/a31.mdl"; # ddchange
    if (-s $mdl_file) {
      my $mdl_header = fits_read_hdr("$mdl_file", "MDL_Models");
      my %mdl = fits_read_bintbl("$mdl_file\[MDL_Models\]");
      my $columns = join(" ",keys(%mdl));
      if ($columns =~ m/parvalue/) {
        $a31_nh = $mdl{parvalue}->at(7);
        $a31_kt = $mdl{parvalue}->at(2);
        $a31_kt_norm = $mdl{parvalue}->at(5);
      } # if ($columns =~ m/parvalue/) {
      if ($columns =~ m/unc_upper/) {
        $a31_nh_err = $mdl{unc_upper}->at(7);
        $a31_kt_err = $mdl{unc_upper}->at(2);
      } # if ($columns =~ m/unc_upper/) {
      $a31_chi = $mdl_header->{F_REDCHI};
      $a31_dof = $mdl_header->{F_DOF};
      $a31_flux = $mdl_header->{EFLUX};
      print $src;
      $a31_kt_flux = $mdl_header->{eflux_ap1};
    } # if (-s $mdl_file) {
###### uncomment for table1:
     printf OUT "%7.4f\t%7.4f\t%7.4f\t%7.4f\t%6.4e\t%6.4e\t%6.4e\t%2d\t%6.4e\t", $a31_nh,a31_nh_err,$a31_kt,$a31_kt_err,$a31_kt_flux,$a31_kt_norm,$a31_chi,$a31_dof,$a31_flux;

    my $bbap_nh=-999;
    my $bbap_nh_err=-999;
    my $bbap_kt=-999;
    my $bbap_kt_err=-999;
    my $bbap_abund=-999;
    my $bbap_abund_err=-999;
    my $bbap_chi=-999;
    my $bbap_dof=-999;
    my $bbap_flux=-999;
    my $kt_flux=-999;
    my $mdl_file="/data/ANCHORS/YAXX/05407/Data/obs5407/src$src/bbap.mdl"; # ddchange
    if (-s $mdl_file) {
      my $mdl_header = fits_read_hdr("$mdl_file", "MDL_Models");
      my %mdl = fits_read_bintbl("$mdl_file\[MDL_Models\]");
      my $columns = join(" ",keys(%mdl));
      if ($columns =~ m/parvalue/) {
        $bbap_nh = $mdl{parvalue}->at(2);
        $bbap_kt = $mdl{parvalue}->at(4);
        $bbap_norm = $mdl{parvalue}->at(7);
      } # if ($columns =~ m/parvalue/) {
      if ($columns =~ m/unc_upper/) {
        $bbap_nh_err = $mdl{unc_upper}->at(2);
        $bbap_kt_err = $mdl{unc_upper}->at(4);
      } # if ($columns =~ m/unc_upper/) {
      $bbap_chi = $mdl_header->{F_REDCHI};
      $bbap_dof = $mdl_header->{F_DOF};
      $bbap_flux = $mdl_header->{EFLUX};
      $kt_flux = $mdl_header->{eflux_ap};
    } # if (-s $mdl_file) {
##    printf "%7.4f\t%7.4f\t%7.4f\t%7.4f\t%6.4e\t%6.4e\t%6.4e\t%2d\t%6.4e\t\n", $bbap_nh,$bbap_nh_err,$bbap_kt,$bbap_kt_err,$bbap_flux,$bbap_norm,$bbap_chi,$bbap_dof,$bbap_flux;

##### uncomment for table1
    printf OUT "%7.4f\t%7.4f\t%7.4f\t%7.4f\t%6.4e\t%6.4e\t%6.4e\t%2d\t%6.4e\t\n", $bbap_nh,$bbap_nh_err,$bbap_kt,$bbap_kt_err,$kt_flux,$bbap_norm,$bbap_chi,$bbap_dof,$bbap_flux;

    my $bbap2_nh=-999;
    my $bbap2_nh_err=-999;
    my $bbap2_kt=-999;
    my $bbap2_kt_err=-999;
    my $bbap2_kt_flux=-999;
    my $bbap2_kt2=-999;
    my $bbap2_kt2_err=-999;
    my $bbap2_kt2_flux=-999;
    my $bbap2_abund=-999;
    my $bbap2_abund_err=-999;
    my $bbap2_chi=-999;
    my $bbap2_dof=-999;
    my $bbap2_flux=-999;
    my $mdl_file="/data/ANCHORS/YAXX/05407/Data/obs5407/src$src/bbap2.mdl"; # ddchange
    if (-s $mdl_file) {
      $mdl_header = fits_read_hdr("$mdl_file", "MDL_Models");
      %mdl = fits_read_bintbl("$mdl_file\[MDL_Models\]");
      my $columns = join(" ",keys(%mdl));
      if ($columns =~ m/parvalue/) {
        $bbap2_nh = $mdl{parvalue}->at(2);
        $bbap2_kt = $mdl{parvalue}->at(4);
        $bbap2_kt_norm = $mdl{parvalue}->at(7);
        $bbap2_kt2 = $mdl{parvalue}->at(9);
        $bbap2_kt2_norm = $mdl{parvalue}->at(12);
      } # if ($columns =~ m/parvalue/) {
      if ($columns =~ m/unc_upper/) {
        $bbap2_nh_err = $mdl{unc_upper}->at(2);
        $bbap2_kt_err = $mdl{unc_upper}->at(4);
        $bbap2_kt2_err = $mdl{unc_upper}->at(9);
      } # if ($columns =~ m/unc_upper/) {
      $bbap2_chi = $mdl_header->{F_REDCHI};
      $bbap2_dof = $mdl_header->{F_DOF};
      $bbap2_flux = $mdl_header->{EFLUX};
      $bbap2_kt_flux = $mdl_header->{eflux_ap1};
      $bbap2_kt2_flux = $mdl_header->{eflux_ap2};
    } # if (-s $mdl_file) {
###### uncomment for table2:
# printf OUT "%7.4f\t%6.4f\t%7.4f\t%7.4f\t%6.4e\t%6.4e\t%7.4f\t%7.4f\t%6.4e\t%6.4e\t%6.4e\t%2d\t%6.4e\t",$bbap2_nh,$bbap2_nh_err,$bbap2_kt,$bbap2_kt_err,$bbap2_kt_flux,$bbap2_kt_norm,$bbap2_kt2,$bbap2_kt2_err,$bbap2_kt2_flux,$bbap2_kt2_norm,$bbap2_chi,$bbap2_dof,$bbap2_flux;

###### uncomment for table3
#printf OUT "%6.4e\t", $bbap2_flux;

  #} #for ($i=0;$i<=$#models;$i++) {

  ## BBLOCKS
  my $dat="/data/ANCHORS/YAXX/05407/Data/obs5407/src$src/bblocks.dat"; # ddchange
  open(DAT,"<$dat");
  $line=<DAT>;
  chomp $line;
  @data=split(/\s+/,$line);
  $bbnum=1;
  $lastn=$data[1];
  @levels=$data[4]*1000.;
  @levels_err=$data[5]*1000.;
  @dt=$data[3]-$data[2];
  print "$data[3] $data[2] "; #debugdt
  print $data[3]-$data[2]; print "\n"; #debugdt
  while ($line=<DAT>) {
    chomp $line;
    @data=split(/\s+/,$line);
    if ($data[0] eq "Change") {last;}
    if ($data[1]-$lastn > 6) {
       print "$lastn\n";  #debug
      push(@levels,$data[4]);
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

###### uncomment for table2:
# printf OUT "%5.2f\t", $bbsig;
  for ($ibblocks=0;$ibblocks<=$#levels;$ibblocks++) {

###### uncomment for table2:
# printf OUT "%1d\t%6.4e\t%6.4e\t%5d\t", $ibblocks,$levels[$ibblocks],$levels_err[$ibblocks],$dt[$ibblocks];
  } # for ($ibblocks=0;$ibblocks<=$#levels;$ibblocks++) {

  printf OUT "\n"; 

  # collect spectral fits
}
#$date=`date`;
#chomp $date;
#print OUT "<created>$date</created>\n";
#print OUT "</root>\n";
close IN;
close OUT;
#
