#!/opt/local/bin/perl
# get images from skyview for each source
# $ARGV[0] is name of file which contains list of source numbers and
# RA,Dec to process
#  read (sample.rdb) (same as yaxx input file)


open(IN,"<$ARGV[0]") || die "Input file $ARGV[0] not found.\n";
while ($inline=<IN>) {
  chomp $inline;
  @line=split(/\s+/,$inline);
  $obs=$line[0];
  $ra=sprintf("%10.6f",$line[1]);
  $dec=sprintf("%10.6f",$line[2]);
  print "$ra $dec\n";
  $src_root="/proj/web-cxc-dmz/htdocs/ANCHORS/".$obs;

  print "working obs $obs\n";
  #############
  # get sky view images
  $isize=0.2000;  # image size (degrees)
  $command="skvbatch file='".$src_root."/dss_6min.gif'  VCOORD='$ra, $dec' SURVEY='Digitized Sky Survey' SFACTR='".$isize."' RETURN=gif GRIDDD='yes'";
  `$command`;
  $command="skvbatch file='".$src_root."/2mass_6min.gif'  VCOORD='$ra, $dec' SFACTR='".$isize."' RETURN=gif IMREDD=2MASS-J IMBLUE=2MASS-H IMGREE=2MASS-K";
  `$command`;
}
close IN;
#
