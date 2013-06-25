#!/usr/bin/perl
# get images from skyview for each source
# $ARGV[0] is name of file which contains list of source numbers and
# RA,Dec to process
#  read (sample.rdb) (same as yaxx input file)

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
  $ra=$line[2];
  $dec=$line[3];
  $src_root=$data_root."/src".$src;

  #if ( ! -s "$src_root/2mass.ps") { # should have this, but make it smarter

    print "working src $src\n";
    #############
    # get sky view images
    $isize=0.01667;  # image size (degrees)
    $command="skvbatch file='".$src_root."/dss.gif'  VCOORD='$ra, $dec' SURVEY='Digitized Sky Survey' SFACTR='".$isize."' RETURN=gif GRIDDD='yes'";
    #`$command`;
    $command="skvbatch file='".$src_root."/2mass_j.fits'  VCOORD='$ra, $dec' SFACTR='".$isize."' RETURN=fits SURVEY=2MASS-J";
    `$command`;
    $command="skvbatch file='".$src_root."/2mass_h.fits'  VCOORD='$ra, $dec' SFACTR='".$isize."' RETURN=fits SURVEY=2MASS-H";
    `$command`;
    $command="skvbatch file='".$src_root."/2mass_k.fits'  VCOORD='$ra, $dec' SFACTR='".$isize."' RETURN=fits SURVEY=2MASS-K";
    `$command`;
    #############
    # make wcs region file
    #  this may be touchy, assumes src.reg is in chandra physical coords
    #  assumes skyview has returned a 150X150 image with source dead center.
    open(REG,"<$src_root/src.reg");
    $regline=<REG>;
    @reg=split(",",$regline);
    close REG;
    open(REG,">/tmp/src_2mass.reg");
    if ($#reg == 4) { # ellipse
      $maj=$reg[2]*0.5/0.2;  # change chandra pixels to 2mass
      $min=$reg[3]*0.5/0.2;
      print REG "ellipse(150,150,$maj,$min,$reg[4]"; # closing ')' already there
    } #if ($#reg == 4) { # ellipse
    if ($#reg == 2) { # circle
      $rad=$reg[2]*0.5/0.2;
      print REG "circle(150,150,$rad)"; 
    } # if ($#reg == 2) { # circle
    close REG;
    `punlearn dmimg2jpg`;
    `pset dmimg2jpg infile=$src_root/2mass_j.fits`;
    `pset dmimg2jpg greenfile=$src_root/2mass_h.fits`;
    `pset dmimg2jpg bluefile=$src_root/2mass_k.fits`;
    `pset dmimg2jpg outfile='$src_root/2mass.jpg'`;
    `pset dmimg2jpg psfile='$src_root/2mass.ps'`;
    `pset dmimg2jpg clobber=yes`;
    `pset dmimg2jpg mode=h`;
    `pset dmimg2jpg showaimpoint=no`;
    `pset dmimg2jpg showgrid=yes`;
    `pset dmimg2jpg gridsize=20`;
    `pset dmimg2jpg scalefunction=log`;
    `pset dmimg2jpg scaleparam=10`;
    `pset dmimg2jpg regionfile="\@/tmp/src_2mass.reg"`;
    `pset dmimg2jpg fontsize=1`;
    `dmimg2jpg`;
    unlink("$src_root/2mass_j.fits");
    unlink("$src_root/2mass_h.fits");
    unlink("$src_root/2mass_k.fits");
  #} #if ( ! -s "$src_root/2mass.ps") {
}
close IN;
#
