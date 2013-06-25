#!/usr/bin/perl
# convert chaser output to anchors_all.html format
#  input chaser.out
#  output anc.txt
# cut and paste in anchors_all.html
# select seq # 200000-2001000, time range, status=all,order by start date,
#  file: detail  in chaser

open(IN,"<chaser.out");
open(OUT,">anc.txt");

<IN>;
<IN>; # skip two header lines

while (<IN>) {
  chomp;
  @line=split(/\t/,$_);
  $line[7] =~ s/ /:/g; # ra
  $line[8] =~ s/ /:/g; # dec
  $line[9] =~ s/observed/archived/; # dec
  @date = split(" ",$line[10]);
  $line[10]=$date[0] ; # just save date, not time
  printf OUT "<tr><td>$line[7]<td>$line[8]";
  printf OUT "<td align=\"center\"><a href=\"0$line[11]\">$line[5]</a>";
  printf OUT "<td>$line[0]<td>$line[11]<td>%.2f",$line[4];
  printf OUT "<td>$line[9]<td>$line[10]";
  printf OUT "<td>";
  printf OUT "<a href=\"http://cxc.harvard.edu/cgi-gen/mp/target.cgi?$line[0]\"";
  printf OUT " class=\"target\">$line[13]</a></tr>\n";
}
close IN;
close OUT;
exit 0;
#
