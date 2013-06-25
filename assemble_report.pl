#!/usr/bin/perl

# usr modified
@sect=qw(rep2banner rep2sumbox rep2spect rep2ir rep2lc rep2quant);
$prog_dir="/data/ANCHORS/YAXX/bin_linux";
$prog_dat="/data/ANCHORS/YAXX/Data";
$xsl_file="$prog_dat/assemble_report2.xsl";
$xsltproc="$prog_dir/xsltproc";
$assemble_pl="$prog_dir/assemble.pl";
$assemble_in="$prog_dat/assemble_report2.in";

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
$book_ps="/data/ANCHORS/YAXX/$obs_dir/book_$data_dir\_report2.ps";
$book_pdf="/data/ANCHORS/YAXX/$obs_dir/book_$data_dir\_report2.pdf";

# copy obs level xml file to tmp - the filename has to be hard coded in xslt
`cp $data_root/../../$data_dir.xml /tmp/obs.xml`;

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
  $xml_file="src$src.xml";
  chdir($src_root);
  if (-s "$data_root/src$src\/src$src\_2mass.xml") {
    `cp $data_root/src$src\/src$src\_2mass.xml /tmp/2mass.xml`;
  } else {
    unlink "/tmp/2mass.xml";
  } #
  for ($isect=0;$isect<=$#sect;$isect++) { # make each sect, defined above
    $command="$xsltproc -o $sect[$isect].tmp -param vobs $data_dir -param vsrcid $src -param vsect \"\'$sect[$isect]\'\" $xsl_file $xml_file";
    ##c#print "$command\n";
    @trap=`$command`;
    
    # must make some changes for latex
    open(TMP,"<$sect[$isect].tmp");
    open(TEX,">$sect[$isect].tex");
    while (<TMP>) {
      s/c_rs/c\\_rs/g;
      print TEX $_;
    }
    close TMP;
    close TEX;
    $command="latex -interaction=batchmode $sect[$isect]";
    ##c#print "$command\n";
    @trap=`$command`;
    $command="dvips -E -q $sect[$isect] -o $sect[$isect].ps";
    ##c#print "$command\n";
    @trap=`$command`;
  } # for ($isect=0;$isect<=$#sect;$isect++) {

  $command="$assemble_pl -m 0.23 $assemble_in \> report2.ps";
  ##c#print "$command\n";
  @trap=`$command`;

  # concat to book
  `cat report2.ps >> $book_ps`;

  # cleanup
  for ($isect=0;$isect<=$#sect;$isect++) { 
    unlink("$sect[$isect].aux");
    unlink("$sect[$isect].dvi");
    unlink("$sect[$isect].log");
    unlink("$sect[$isect].tex");
    unlink("$sect[$isect].ps");
  }  # for ($isect=0;$isect<=$#sect;$isect++) {
} # while ($inline=<IN>) {
close IN;

# make pdf book with page breaks
`/usr/bin/ps2pdf14 $book_ps $book_pdf`;

chdir($cwd);
#
