#!/usr/bin/perl

$data_root="/data/ANCHORS/YAXX/04503/Data/obs4503";
$infile=$data_root."/../../do_hardness.out";
open(IN,"<$infile") || die "Input file $infile not found.\n";

while ($inline=<IN>) {
  chomp $inline;
  @line=split(/\s+/,$inline);
  $src=$line[1];
  $src_root=$data_root."/src".$src;
  print "$src_root\n";
  chdir("$src_root");
  $tex_in=$src_root."/report.tex";
  $tex_root=$src_root."/report_1";
  $tex_out=$tex_root.".tex";
  $ps_out=$tex_root.".ps";
  open(INTEX,"<$tex_in");
  open(OUTTEX,">$tex_out");
  while (<INTEX>) {
    s/Obsid/\%\%Obsid/;
    s/CCD /\%\%CCD /;
    s/Source/\%\%Source/;
    s/Classification/\%\%Classification/;
    s/Redshift/\%\%Redshift/;
    s/\\\\\\centerline/\\\\\n\\centering/;
    s/\& apec //;
    s/\& apec2 //;
    s/

    if (/\\end\{tabular\}\}/) {
      # add quantile and hr tables
      print OUTTEX "\\end\{tabular\}\n";
      print OUTTEX "\\vspace*\{\.2in\} \\\\\n";
      print OUTTEX "\\begin\{tabular\}\{l|ccc\}\n";
      print OUTTEX "\\multicolumn{4}{c}{Quantile Analysis} \\\\\n";
      print OUTTEX "\\hline\n";
      print OUTTEX "\& 25\\% \& 50\\% \& 75\\% \\\\\n";
      print OUTTEX "\\hline\n";
      $qfile=$src_root."/quantile.dat";
      open(QIN,"<$qfile");
      <QIN>;
      $qinline=<QIN>;
      chomp $qinline;
      @qline=split(/\s+/,$qinline);
      print OUTTEX "(keV) & $qline[1] & $qline[3] & $qline[5] \\\\\n";
      print OUTTEX "error & $qline[2] & $qline[4] & $qline[6] \\\\\n";
      print OUTTEX "\\hline\n";
      print OUTTEX "\\end{tabular}\n";
      print OUTTEX "\\vspace*{.2in} \\\\\n";
      print OUTTEX "\\begin{tabular}{ccc}\n";
      print OUTTEX "\\multicolumn{3}{c}{Hardness Ratios} \\\\\n";
      print OUTTEX "\\hline\n";
      print OUTTEX "HR1 & HR2 & HR3 \\\\\n";
      print OUTTEX "\\hline\n";
      print OUTTEX "$line[2] &$line[3]  &$line[4]  \\\\\n";
      print OUTTEX "\\hline\n";
    } # if (/\\end\{tabular\}\}/) {

    if (/\\end\{document\}/) {
      # add bblock plot
      print OUTTEX "\\resizebox{2.25in}{!}{\\includegraphics{bblocks_plot.ps}}\n";
    } # if (/\\end\{tabular\}\}/) {

    print OUTTEX $_;
  } # while (<INTEX>) {
  close INTEX;
  close OUTTEX;
  $command="latex -interaction=batchmode report_1";
  print "$command\n";
  `$command`;
  $command="dvips report_1 -o $ps_out";
  print "$command\n";
  `$command`;
} # while ($inline=<IN>) {
close IN;
#
