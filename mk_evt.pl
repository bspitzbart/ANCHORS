#! /usr/bin/perl

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

$evt_file="bblocks_src_evt.fits";
$bkg_file="src_bkg.fits";

open(IN,"<$ARGV[0]") || die "Input file $ARGV[0] not found.\n";
$inline=<IN>; # skip first 2 header lines
$inline=<IN>; # skip first 2 header lines
while ($inline=<IN>) {
  chomp $inline;
  @line=split(/\s+/,$inline);
  @src_str=split("_",$line[0]);
  $src=$src_str[1];
  $src_root=$data_root."/src".$src;
  $command="dmcopy '".$src_root."/acis_evt2.fits[sky=region(".$src_root."/src.reg)]' ".$evt_file." clobber=yes";
  #print "$command\n"; #dbug
  `$command`;
  $command="dmcopy '".$src_root."/acis_evt2.fits[sky=region(".$src_root."/bkg.reg)]' ".$bkg_file." clobber=yes";
  `$command`;

  $command="mv ".$evt_file." ".$src_root."/src".$src."_evt.fits";
  `$command`;
  $command="mv ".$bkg_file." ".$src_root."/src".$src."_bkg_evt.fits";
  `$command`;

} #while ($inline=<IN>) {
close IN;
