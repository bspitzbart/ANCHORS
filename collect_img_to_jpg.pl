#!/usr/bin/perl
# make color chandra image
#  read (src.txt) (same as yaxx input file)

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
$outxml="/data/ANCHORS/YAXX/$obs_dir/$data_dir.xml";

$cwd=`pwd`;
open(IN,"<$ARGV[0]") || die "Input file $ARGV[0] not found.\n";
$inline=<IN>; # skip first 2 header lines
$inline=<IN>; # skip first 2 header lines
while ($inline=<IN>) {
  chomp $inline;
  @line=split(/\s+/,$inline);
  @src_str=split("_",$line[0]);
  $src=$src_str[1];
  $src_root="$data_root/src$src";
  $ra=$line[2];
  $dec=$line[3];

  `punlearn dmimg2jpg`;
  `punlearn dmcopy`;
  `pset dmcopy clobber=yes`;
  `pset dmcopy mode=h`;
  #############
  # make wcs region file
  open(REG,"<$src_root/src.reg");
  $regline=<REG>;
  @reg=split(",",$regline);
  close REG;
  @sky=split(/\(/,$reg[0]);
  $sky_x=$sky[1];
  $sky_y=$reg[1];
  ## use src.reg now
  ##open(REG,">/tmp/src_wcs.reg");
  ##if ($#reg == 4) { # ellipse
  ##  $maj=$reg[2]/2;
  ##  $min=$reg[3]/2;
  ##  print REG "ellipse($ra,$dec,$maj\",$min\",$reg[4]"; # closing ')' already there
  ##} #if ($#reg == 4) { # ellipse
  ##if ($#reg == 2) { # circle
  ##  $rad=$reg[2]/2;
  ##  print REG "circle($ra,$dec,$rad\")";
  ##} # if ($#reg == 2) { # circle
  ##close REG;
  $xmin=$sky_x-60.0;  # make 1' image (to match 2mass from skyview)
  $xmax=$sky_x+60.0;
  $ymin=$sky_y-60.0;
  $ymax=$sky_y+60.0;
  `dmcopy '$src_root/acis_evt2.fits[energy=500:1700][bin x=$xmin:$xmax:1,y=$ymin:$ymax:1]' red.fits`;
  `dmcopy '$src_root/acis_evt2.fits[energy=1700:2400][bin x=$xmin:$xmax:1,y=$ymin:$ymax:1]' green.fits`;
  `dmcopy '$src_root/acis_evt2.fits[energy=2400:8000][bin x=$xmin:$xmax:1,y=$ymin:$ymax:1]' blue.fits`;
  `punlearn dmimg2jpg`;
  `pset dmimg2jpg infile=red.fits`;
  `pset dmimg2jpg greenfile=green.fits`;
  `pset dmimg2jpg bluefile=blue.fits`;
  `pset dmimg2jpg outfile='$src_root/chandra.jpg'`;
  `pset dmimg2jpg psfile='$src_root/chandra.ps'`;
  `pset dmimg2jpg clobber=yes`;
  `pset dmimg2jpg mode=h`;
  `pset dmimg2jpg showaimpoint=no`;
  `pset dmimg2jpg showgrid=no`;
  `pset dmimg2jpg gridsize=20`;
  `pset dmimg2jpg scalefunction=log`;
  `pset dmimg2jpg scaleparam=10`;
  #`pset dmimg2jpg regionfile="\@/tmp/src_wcs.reg"`;
  #`pset dmimg2jpg regionfile="\@$src_root/all.reg"`;
  `pset dmimg2jpg regionfile="\@$src_root/src.reg"`;
  #`pset dmimg2jpg fontsize=1`;
  `dmimg2jpg`;
  unlink("red.fits");
  unlink("green.fits");
  unlink("blue.fits");

} # while ($inline=<IN>) {
#
