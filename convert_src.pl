#!/usr/bin/perl
#
#create the src.reg and calc_theta_phi.lst files
#------------------------------
$argc = @ARGV;
$argc >= 1  or die "USAGE: convert_src.pl  <source file>\n";

$srcfile=@ARGV[0];

open(SRC,$srcfile) || die "Cannot open $srcfile\n";

while(<SRC>){
  $my_line=trim($_);
  push(@lines,$my_line);
}
close(SRC);
unlink($srcfile);
open(OUT,">> $srcfile"); 

    
$phi="/data/ANCHORS/YAXX/bin/calc_theta_phi.lst";
if (-f $phi){
  unlink($phi);
}
open(OUT2,">> $phi") || die "Cannot open $phi\n";

foreach $line (@lines){
      #only lines that start with a number
      if ( $line =~ /^[0-9]/){
         @itm=split(/\s+/,$line); 
	 $mystr="$itm[1]($itm[2],$itm[3],$itm[5],$itm[6],$itm[7]";
	 $mystr=~s/\]//g;
	 $mystr=~s/\)//g;
	 print OUT "$mystr)\n";
	 $mystr2="$itm[2] $itm[3]";
	 $mystr2=~s/\)//g;
         $mystr2=~s/,/ /g;
	 print OUT2 "$mystr2\n";
      }
}
close(OUT);
close(OUT2);
exit;







sub trim {
    my @out = @_;
    for (@out) {
        s/^\s+//;
        s/\s+$//;
    }
    return wantarray ? @out : $out[0];
}
