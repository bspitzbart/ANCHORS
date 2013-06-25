#! /usr/bin/perl

if ($#ARGV != 1) {
  die "Usage:\n  $0 <sample.rdb> <obsid>\n";
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
} # while ($count < 5) 

$data_root="/data/ANCHORS/YAXX/$obs_dir/Data/obs$data_dir";

$repfile="report2.ps";
$tmp_book1="/data/ANCHORS/YAXX/$obs_dir/tmp_book1";
$tmp_book2="/data/ANCHORS/YAXX/$obs_dir/tmp_book2";
$final_book="/data/ANCHORS/YAXX/$obs_dir/book_".$obs_dir."_report2.ps";
$final_pdf="/data/ANCHORS/YAXX/$obs_dir/book_".$obs_dir."_report2.pdf";

open(OUT,">$tmp_book1");
close OUT;

open(IN,"<$ARGV[0]") || die "Input file $ARGV[0] not found.\n";
$inline=<IN>; # skip first 2 header lines
$inline=<IN>; # skip first 2 header lines

while ($inline=<IN>) {
  chomp $inline;
  @line=split(/\s+/,$inline);
  @src_str=split("_",$line[0]);
  $src=$src_str[1];
  $src_root=$data_root."/src".$src;
  $command="cat ".$src_root."/".$repfile." >> ".$temp_book1;
  `$command`;


}
close IN;

#`hprint -fix -out $temp_book2 $temp_book1`
#`psnup -n 4 $temp_book2 $final_book`
`ps2pdf $temp_book1 tmp_book.pdf`;
`pdf2ps tmp_book.pdf tmp_book.ps`;
`psnup -n 4 tmp_book.ps $final_book`;
`ps2pdf $final_book $final_pdf`;
