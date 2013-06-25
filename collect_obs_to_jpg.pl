#!/opt/local/bin/perl
# make color chandra image
#  read (src.txt) (same as yaxx input file)

open(IN,"<$ARGV[0]") || die "Input file $ARGV[0] not found.\n";
while ($inline=<IN>) {
  chomp $inline;
  @line=split("/",$inline);
  $src=$line[5];
  $src_root="/proj/web-cxc-dmz/htdocs/ANCHORS/".$src;
  print "$src\n";
  `punlearn dmimg2jpg`;
  `punlearn dmcopy`;
  `pset dmcopy clobber=yes`;
  `pset dmcopy mode=h`;
  #############
  $xmin=4096.0-720.0;  # make 12' image (to match 2mass from skyview)
  $xmax=4096.0+720.0;
  $ymin=4096.0-720.0;
  $ymax=4096.0+720.0;
  `dmcopy '$inline\[energy=500:1700\]\[bin x=$xmin:$xmax:1,y=$ymin:$ymax:1\]' red.fits`;
  `dmcopy '$inline\[energy=1700:2400\]\[bin x=$xmin:$xmax:1,y=$ymin:$ymax:1\]' green.fits`;
  `dmcopy '$inline\[energy=2400:8000\]\[bin x=$xmin:$xmax:1,y=$ymin:$ymax:1\]' blue.fits`;
  `punlearn dmimg2jpg`;
  `pset dmimg2jpg infile=red.fits`;
  `pset dmimg2jpg greenfile=green.fits`;
  `pset dmimg2jpg bluefile=blue.fits`;
  `pset dmimg2jpg outfile='$src_root/chandra_6min.jpg'`;
  `pset dmimg2jpg mode=h`;
  `pset dmimg2jpg showaimpoint=no`;
  `pset dmimg2jpg showgrid=no`;
  `pset dmimg2jpg gridsize=20`;
  `pset dmimg2jpg scalefunction=log`;
  `pset dmimg2jpg scaleparam=10`;
  `dmimg2jpg`;
  unlink("red.fits");
  unlink("green.fits");
  unlink("blue.fits");
} # while ($inline=<IN>) {
#
