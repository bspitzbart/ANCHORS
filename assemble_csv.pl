#!/usr/bin/perl
# convert xml into ascii tables:
# 1- top (ra,dec,off_ax,cnts,quant,etc.)
# 2- bblocks (ra,dec,bayesian blocks)
# 3- spec (ra,dec,spectral fits)
# 4- ir (offset,j,h,k,flags)
# 5- 09/21/10 new table for lightcurves

# usr modified
$prog_dir="/data/ANCHORS/YAXX/bin_linux";
$prog_dat="/data/ANCHORS/YAXX/Data";
$xsl_file="$prog_dat/assemble_csv.xsl";
$xsltproc="$prog_dir/xsltproc";

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
# put output files here:
$out_root="/data/ANCHORS/YAXX/$obs_dir";

open(OUTTOP,">$out_root/$data_dir.csv");
print OUTTOP "SRC,,,,,,,EXPOSURE,OFF_AX,,,,,,,\n";
print OUTTOP "ID,RA,DEC,RAW_CNTS,NET_CNTS,NET_FLUX,NET_FLUX_ERR";
print OUTTOP ",TIME,DIST.,CCD_ID";
print OUTTOP ",Q25,Q25_ERR,Q50,Q50_ERR,Q75,Q75_ERR\n";
print OUTTOP ",,,,,p/cm^2/s,p/cm^2/s,sec,arcsec,,keV,keV,keV,keV,keV,keV\n";

open(OUTBBLK,">$out_root/$data_dir\_bblocks.csv");
print OUTBBLK "ID,RA,DEC,N0,RATE0,ERR0,TIME0,N1,RATE1,ERR1,TIME1,...\n";
print OUTBBLK ",,,,cnts\/ksec,cnts\/ksec,sec,,cnts\/ksec,cnts\/ksec,sec,...\n";

open(OUTLC,">$out_root/$data_dir\_lc.csv");
print OUTLC "ID,RA,DEC,GLvary_odds,GLvary_prob,GLvary_index,N_BBlocks\n";

open(OUTSPEC,">$out_root/$data_dir\_spec.csv");
print OUTSPEC ",,,cstat,-->,,,,";
print OUTSPEC ",,,ABS.,UNABS.,UNABS.,RED.,DEG.OF";
print OUTSPEC ",,,c_rs,-->,,,,";
print OUTSPEC ",,,ABS.,UNABS.,UNABS.,RED.,DEG.OF";
print OUTSPEC ",c_rs2,-->,,,,";
print OUTSPEC ",,,ABS.,UNABS.,UNABS.,RED.,DEG.OF";
print OUTSPEC ",c_rs2a,-->,,,,";
print OUTSPEC ",,,ABS.,UNABS.,UNABS.,RED.,DEG.OF\n";
print OUTSPEC "ID,RA,DEC,NH,NH_ERR,KT1,KT1_ERR,KT2,KT2_ERR";
print OUTSPEC ",ABUND,ABUND_ERR,FLUX,KT1_FLUX,KT2_FLUX,CHI^2,FREEDOM";
print OUTSPEC ",NH,NH_ERR,KT1,KT1_ERR,KT2,KT2_ERR";
print OUTSPEC ",ABUND,ABUND_ERR,FLUX,KT1_FLUX,KT2_FLUX,CHI^2,FREEDOM";
print OUTSPEC ",NH,NH_ERR,KT1,KT1_ERR,KT2,KT2_ERR";
print OUTSPEC ",ABUND,ABUND_ERR,FLUX,KT1_FLUX,KT2_FLUX,CHI^2,FREEDOM";
print OUTSPEC ",NH,NH_ERR,KT1,KT1_ERR,KT2,KT2_ERR";
print OUTSPEC ",ABUND,ABUND_ERR,FLUX,KT1_FLUX,KT2_FLUX,CHI^2,FREEDOM\n";
print OUTSPEC ",,,10^22\/cm^2,10^22\/cm^2,keV,keV,N/A,N/A";
print OUTSPEC ",,,erg\/cm^2\/s,erg\/cm^2\/s,N\/A,,";
print OUTSPEC ",10^22\/cm^2,10^22\/cm^2,keV,keV,N/A,N/A";
print OUTSPEC ",,,erg\/cm^2\/s,erg\/cm^2\/s,N\/A,,";
print OUTSPEC ",10^22\/cm^2,10^22\/cm^2,keV,keV,keV,keV";
print OUTSPEC ",,,erg\/cm^2\/s,erg\/cm^2\/s,erg\/cm^2\/s,,";
print OUTSPEC ",10^22\/cm^2,10^22\/cm^2,keV,keV,keV,keV";
print OUTSPEC ",,,erg\/cm^2\/s,erg\/cm^2\/s,erg\/cm^2\/s,,\n";

open(OUTIR,">$out_root/$data_dir\_ir.csv");
print OUTIR "SRC,,,,,IR,IR,OFFSET,J,J,H,H,K,K,QUAL\n";
print OUTIR "ID,RA,DEC,RA,DEC,RA,DEC,arcsec,MAG,ERR,MAG,ERR,MAG,ERR,FLAGS\n";

open(IN,"<$ARGV[0]") || die "Input file $ARGV[0] not found.\n";
$inline=<IN>; # skip first 2 header lines
$inline=<IN>; # skip first 2 header lines
while ($inline=<IN>) {
  chomp $inline;
  @line=split(/\s+/,$inline);
  @src_str=split("_",$line[0]);
  $src=$src_str[1];
  $src_root="$data_root/src$src";
  $xml_file="$src_root/src$src.xml";

  $command="$xsltproc -param vobs $data_dir -param vsrcid $src -param vsect \"\'top\'\" $xsl_file $xml_file";
  ##c#print "$command\n";
  @trap=`$command`;
  for ($itrap=0;$itrap<=$#trap;$itrap++) {
    chomp $trap[$itrap];
    $trap[$itrap]=~s/\s+//;
    print OUTTOP "$trap[$itrap]";
  }
  print OUTTOP "\n";

  $command="$xsltproc -param vobs $data_dir -param vsrcid $src -param vsect \"\'spec\'\" $xsl_file $xml_file";
  ##c#print "$command\n";
  @trap=`$command`;
  for ($itrap=0;$itrap<=$#trap;$itrap++) {
    chomp $trap[$itrap];
    $trap[$itrap]=~s/\s+//;
    print OUTSPEC $trap[$itrap];
  }
  print OUTSPEC "\n";

  $command="$xsltproc -param vobs $data_dir -param vsrcid $src -param vsect \"\'bblocks\'\" $xsl_file $xml_file";
  ##c#print "$command\n";
  @trap=`$command`;
  for ($itrap=0;$itrap<=$#trap;$itrap++) {
    chomp $trap[$itrap];
    $trap[$itrap]=~s/\s+//;
    print OUTBBLK $trap[$itrap];
  }
  print OUTBBLK "\n";

  $command="$xsltproc -param vobs $data_dir -param vsrcid $src -param vsect \"\'lc\'\" $xsl_file $xml_file";
  ##c#print "$command\n";
  @trap=`$command`;
  for ($itrap=0;$itrap<=$#trap;$itrap++) {
    chomp $trap[$itrap];
    $trap[$itrap]=~s/\s+//;
    print OUTLC $trap[$itrap];
  }
  print OUTLC "\n";

  if (-s "$src_root/src$src\_2mass.xml") {
    `cp $src_root/src$src\_2mass.xml /tmp/2mass.xml`;
    $command="$xsltproc -param vobs $data_dir -param vsrcid $src -param vsect \"\'ir\'\" $xsl_file $xml_file";
    ##c#print "$command\n";
    @trap=`$command`;
    for ($itrap=0;$itrap<=$#trap;$itrap++) {
      chomp $trap[$itrap];
      $trap[$itrap]=~s/\s+//;
      print OUTIR $trap[$itrap];
    } 
    unlink "/tmp/2mass.xml";
  } else {
    print OUTIR "$src"
  }  # if (-s "$src_root/src$src\_2mass.xml) {
  print OUTIR "\n";

} # while ($inline=<IN>) {
close IN;
close OUTTOP;
close OUTBBLK;
close OUTLC;
close OUTSPEC;
close OUTIR;
#
