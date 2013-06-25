#!/usr/bin/perl

# usr modified
@sect=qw(rep2banner rep2sumbox rep2spect rep2ir rep2lc rep2quant);
$prog_dir="/data/mta4/CVS_test/ANCHORS_PROC";
$xsl_file="$prog_dir/assemble_report2.xsl";
$xsltproc="$prog_dir/xsltproc";
$assemble_pl="$prog_dir/assemble.pl";
$assemble_in="$prog_dir/assemble_report2.in";

$command="$assemble_pl -m 0.23 $assemble_in \>\! report2.ps";
print "$command\n";
`$command`;
#
