#!/usr/bin/env /proj/axaf/bin/perl
##!/opt/local/bin/perl
# collect nH,kT,abund,chi^2, etc. from YAXX fits
# $ARGV[0] is name of file which contains list of source numbers and
# RA,Dec to process
# sample.rdb

use coords;

if ($#ARGV < 1) {
  die "Usage:\n  $0 <infile> <obsid> [ncp_prior]\n";
}
$prior = 3;  #default 95%
$label="";   #don't label if using default prior - for back compatability
if ($#ARGV = 2) {
  $prior=$ARGV[2];
  $label="_".$ARGV[2];
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

open(OUT,">bblocks$label\.csv");
print OUT "ID,RA,DEC,NBLOCKS,N0,RATE0,ERR0,TIME0,N1,RATE1,ERR1,TIME1,...\n";
print OUT ",,,,,cnts/ksec,cnts/ksec,sec,,cnts/ksec,cnts/ksec,sec,...\n";

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
 
  ## BBLOCKS
  my $dat="$data_root/src$src/bblocks$label\.dat"; # ddchange
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

  $nblocks=$#levels+1;
  print OUT "$src,$ra_str,$dec_str,$nblocks";
  for ($ibblocks=0;$ibblocks<=$#levels;$ibblocks++) {
    printf OUT ",$ibblocks";
    printf OUT ",$levels[$ibblocks]";
    printf OUT ",$levels_err[$ibblocks]";
    printf OUT ",$dt[$ibblocks]";
  } # for ($ibblocks=0;$ibblocks<=$#levels;$ibblocks++) {
  printf OUT "\n";

} # while ($inline=<IN>) {
close IN;
close OUT;
#
