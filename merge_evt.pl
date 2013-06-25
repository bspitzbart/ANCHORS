#!/opt/local/bin/perl
# set up web area for given obsid
# $ARGV[0] is name of file which contains list of source numbers and
# RA,Dec to process
#  read (sample.rdb) (same as yaxx input file)

use coords;

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
$html_root="/proj/web-cxc-dmz/htdocs/ANCHORS/$obs_dir";
$outxml="/data/ANCHORS/YAXX/$obs_dir/$data_dir.xml";

open(IN,"<$ARGV[0]") || die "Input file $ARGV[0] not found.\n";
$inline=<IN>; # skip first 2 header lines
$inline=<IN>; # skip first 2 header lines
while ($inline=<IN>) {
  chomp $inline;
  @line=split(/\s+/,$inline);
  @src_str=split("_",$line[0]);
  $src=$src_str[1];
  $src_root="$data_root/src$src";
 
  # make new name
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
  print "$ra_str $dec_str\n";
  print "@strra @strdec\n";
  if ($strdec[0] >= 0) { $strdec[0]="+".$strdec[0]; }
  $src_name=join("",@strra).join("",@strdec);
  $src_html="$html_root/$src_name";

  `cp $src_root/src$src\_evt.fits $src_html/src_evt.fits`;
  `cp $src_root/src$src\_bkg_evt.fits $src_html/bkg_evt.fits`;
  `cp $src_root/src.reg $src_html`;
  `cp $src_root/bkg.reg $src_html`;

} # while ($inline=<IN>) {
close IN;
#
