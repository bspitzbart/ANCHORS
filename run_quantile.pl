#!/usr/local/bin/perl
# run quantile routines on a list of sources

@frac=qw(0.25 0.50 0.75);
$range="0.3:8.0";

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

$infile="bblocks.in";
$outfile="quantiles.dat";

$evt_file="bblocks_src_evt.fits";

$tmp_dump_file="quant_dump.txt";
$tmp_energy_list="quant_list.txt";
open(IN,"<$ARGV[0]") || die "Input file $ARGV[0] not found.\n";
$inline=<IN>; # skip first 2 header lines
$inline=<IN>; # skip first 2 header lines
while ($inline=<IN>) {
  chomp $inline;
  @line=split(/\s+/,$inline);
  @src_str=split("_",$line[0]);
  $src=$src_str[1];

  $evt_file="bblocks_src_evt.fits";
  $src_root=$data_root."/src".$src;

  $command="dmcopy '".$src_root."/acis_evt2.fits[sky=region(".$src_root."/src.reg)]' ".$evt_file." clobber=yes";
  #print "$command\n"; #dbug
  `$command`;

  # quantile.pl takes a text file of energies, make that now, for each src
  $command="dmlist '".$evt_file."[cols energy]' data > ".$tmp_dump_file;
  #print "$command\n"; #debug
  `$command`;
  open(EN,"<$tmp_dump_file");
  for ($j=0;$j<=6;$j++) {
    <EN>;
  }
  open(OUT,">$tmp_energy_list");
  while ($energy=<EN>) {
    chomp $energy;
    @inline=split(" ",$energy);
    $kev=$inline[1]/1000.0;
    print OUT "$kev\n";
  }
  close OUT;
  close EN;
  #undo unlink $tmp_dump_file;

  $command="quantile.pl -frac ";
  for ($j=0;$j<=$#frac-1;$j++) {
    $command.="$frac[$j],";
  }
  $command.="$frac[$#frac]";
  $command.=" -src ".$tmp_energy_list;
  $command.=" -range ".$range;
  #print $command; # debug
  @result=`$command`;
  
  open(RESULTS,">$src_root/quantile.dat");
  print RESULTS "src ";
  for ($i=0;$i<=$#frac;$i++) {
    print RESULTS "$frac[$i] $frac[$i]_err ";
  }
  print RESULTS "\n";

  print RESULTS "$src ";
  for ($j=$#result-$#frac;$j<=$#result;$j++) {
    @res_line=split(" ",$result[$j]);
    print RESULTS "$res_line[1] $res_line[2] ";
  }
  print RESULTS "\n";
  close RESULTS;
  unlink $tmp_energy_list;

}
close IN;
#
