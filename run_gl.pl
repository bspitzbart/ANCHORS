#! /usr/bin/perl
# run gregory-laredo routines on a list of sources
# * uses GLvary *

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

open(IN,"<$ARGV[0]") || die "Input file $ARGV[0] not found.\n";
$inline=<IN>; # skip first 2 header lines
$inline=<IN>; # skip first 2 header lines
while ($inline=<IN>) {
  chomp $inline;
  @line=split(/\s+/,$inline);
  @src_str=split("_",$line[0]);
  $src=$src_str[1];
  $src_root=$data_root."/src".$src;
  $evt_file=$src_root."/src_evt.fits";
  $infile=$src_root."/GLvary.in";
  $outfile=$src_root."/GLvary.out";

  $command="dmlist '".$evt_file."[cols time]' data | tail -n +8 | awk '{print \$2}' > ".$infile;
  `$command`;
  $command="GLvary_linux -i ".$infile." > ".$outfile;
  `$command`;

} #while ($inline=<IN>) {
close IN;
