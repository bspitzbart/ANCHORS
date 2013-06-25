#!/usr/bin/env /proj/axaf/bin/perl
##!/opt/local/bin/perl
# parse gregory-laredo lightcurve output
# $ARGV[0] is name of file which contains list of source numbers and
# RA,Dec to process
# sample.rdb

use coords;

if ($#ARGV < 1) {
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

open(OUT,">$data_dir\_gl\.csv");
print OUT "ID,RA,DEC,Prob,var_index,sig_frac3,sig_frac5,m_bins,m_prob,med_F,min_F,max_F,max(dr/dt)(1/med_F),tstart_max\n";
print OUT ",,,,,,,,,cnts/ksec,cnts/ksec,cnts/ksec,scaled cnts/ks/ks,sec\n";

$prob=999;
$sig_frac3=999;
$sig_frac5=999;
$var_index=999;
$m_bins=999;
$m_prob=999;
$med_F=999;
$max_der=999;;
$max_der_t=999;;

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
  if ($strdec[0] >= 0) { $strdec[0]="+".$strdec[0]; }
  $src_name=join("",@strra).join("",@strdec);
 
  ## GLvary
  my $dat="$data_root/src$src/GLvary.out"; # ddchange
  open(DAT,"<$dat");
  $read_m=0;  # haven't found m probability section yet
  $read_f=0;  # haven't found flux rate section yet
  while ($line=<DAT>) {
    #print $line;  #debug
    chomp $line;
    @data=split(/\s+/,$line);
    if ($line =~ m/Probability of a variable signal/) {
      $prob=$data[7];
    }
    if ($line =~ m/Fraction of light curve within/) {
      $sig_frac3=$data[11];
      chop $sig_frac3;
      $sig_frac5=$data[14];
    }
    if ($line =~ m/Variability index/) {
      $var_index=$data[3];
    }
    if ($line =~ m/m with maximum odds/) {
      $m_bins=$data[7];
      $read_m=1;
      while ($read_m) {
        $line=<DAT>;
        chomp $line;
        $line =~ s/^ //g;
        @data=split(/\s+/,$line);
        if ($data[1] eq "Time" && $data[2] eq "<F>" && $data[3] eq "sigma") {
          $read_m = 0; # extra check, in case of bad format
                       #  we've missed m_prob, so skip
        }
        if ($data[0] == $m_bins) {
          $m_prob=$data[1];
          $read_m=0;
        } # if ($data[1] == $m_bins) {
      } # while ($read_m) {
    } # if ($line =~ m/m with maximum odds/) {
    if ($data[1] eq "Time" && $data[2] eq "<F>" && $data[3] eq "sigma") {
      $read_f=1;  # unused ?
      <DAT>;  #skip one blank line
      $line=<DAT>;  #read first line
      chomp $line;
      @data=split(/\s+/,$line);
      @time=$data[0];
      @rate=$data[1]*1000.;
      @sigma=$data[2]*1000.;  # unused

      $idat=1 ; # keep an index
      $max_der=0;
      while ($line=<DAT>) {  #read rest
        chomp $line;
        @data=split(/\s+/,$line);
        $data[1]=$data[1]*1000. ; # change to ksec
        $data[2]=$data[2]*1000. ; # change to ksec
        push(@time,$data[0]);
        push(@rate,$data[1]);
        push(@sigma,$data[2]);  # unused
        $deriv=($rate[$idat]-$rate[$idat-1])/($time[$idat]-$time[$idat-1]);
        if ($deriv > $max_der) { 
          $max_der = $deriv; 
          $max_der_t = $time[$idat-1];
        } # if ($deriv > $max_der) { 
        $idat++;
      } # while ($line=<DAT>) {  #read rest
    }  # if ($data[1] eq "Time" && $data[2] eq "<F>" && $data[3] eq "sigma") {
  } # while ($line=<DAT>) {
  # should be end of file

  @sort_f = sort { $a <=> $b } @rate;
  $med_F = $sort_f[int(($#sort_f+1)/2)];
  $min_F = $sort_f[0];
  $max_F = $sort_f[$#sort_f];

  $max_der=$max_der/$med_F;

  printf OUT "$src,$ra_str,$dec_str,$prob,$var_index,%5.3f,%5.3f,$m_bins,%5.3f,%5.3f,%5.3f,%5.3f,%.3f,$max_der_t\n",$sig_frac3,$sig_frac5,$m_prob,$med_F,$min_F,$max_F,$max_der;

} # while ($inline=<IN>) {
close IN;
close OUT;
#
