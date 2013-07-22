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
$xsl_file="$prog_dat/assemble_apec.xsl";
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

open(OUTAPEC,">$out_root/$data_dir\_apec.csv");
print OUTAPEC ",,,c_ap,-->,,,,";
print OUTAPEC ",,,ABS.,UNABS.,UNABS.,RED.,DEG.OF";
print OUTAPEC ",c_ap2,-->,,,,";
print OUTAPEC ",,,ABS.,UNABS.,UNABS.,RED.,DEG.OF";
print OUTAPEC ",c_ap2a,-->,,,,";
print OUTAPEC ",,,ABS.,UNABS.,UNABS.,RED.,DEG.OF\n";
print OUTAPEC "ID,RA,DEC,";
print OUTAPEC "NH,NH_ERR,KT1,KT1_ERR,KT2,KT2_ERR";
print OUTAPEC ",ABUND,ABUND_ERR,FLUX,KT1_FLUX,KT2_FLUX,CHI^2,FREEDOM";
print OUTAPEC ",NH,NH_ERR,KT1,KT1_ERR,KT2,KT2_ERR";
print OUTAPEC ",ABUND,ABUND_ERR,FLUX,KT1_FLUX,KT2_FLUX,CHI^2,FREEDOM";
print OUTAPEC ",NH,NH_ERR,KT1,KT1_ERR,KT2,KT2_ERR";
print OUTAPEC ",ABUND,ABUND_ERR,FLUX,KT1_FLUX,KT2_FLUX,CHI^2,FREEDOM\n";
print OUTAPEC ",,,10^22\/cm^2,10^22\/cm^2,keV,keV,N/A,N/A";
print OUTAPEC ",,,erg\/cm^2\/s,erg\/cm^2\/s,N\/A,,";
print OUTAPEC ",10^22\/cm^2,10^22\/cm^2,keV,keV,N/A,N/A";
print OUTAPEC ",,,erg\/cm^2\/s,erg\/cm^2\/s,N\/A,,";
print OUTAPEC ",10^22\/cm^2,10^22\/cm^2,keV,keV,keV,keV";
print OUTAPEC ",,,erg\/cm^2\/s,erg\/cm^2\/s,erg\/cm^2\/s,,";
print OUTAPEC ",10^22\/cm^2,10^22\/cm^2,keV,keV,keV,keV";
print OUTAPEC ",,,erg\/cm^2\/s,erg\/cm^2\/s,erg\/cm^2\/s,,\n";

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

  $command="$xsltproc -param vobs $data_dir -param vsrcid $src -param vsect \"\'apec\'\" $xsl_file $xml_file";
  ##c#print "$command\n";
  @trap=`$command`;
  for ($itrap=0;$itrap<=$#trap;$itrap++) {
    chomp $trap[$itrap];
    $trap[$itrap]=~s/\s+//;
    print OUTAPEC $trap[$itrap];
  }
  print OUTAPEC "\n";

} # while ($inline=<IN>) {
close IN;
close OUTAPEC;
#
