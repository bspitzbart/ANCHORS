#!/usr/bin/perl
# -*- perl -*-  Set perl mode for emacs
#
# Include a number of epsf files, with origins specified wrt the bottom
# left, and measured in inches. Optionally, specify the x or y size too
#
# For example, if the file assemble.in looks like:
#	#
#	# Files to be put together into a postscript page
#	#
#	#file xoff yoff [xsize [ysize]]		(dimensions in inches)
#	foo.ps 1 1 0 .5
#	bar.ps 1.5 2 2 2
# the command
#	assemble assemble.in | lpr
# will put file foo.ps at origin (1,1), with a height of 0.5", and its proper
# aspect ration, and bar.ps at (1.5,2) with both width and height 2"
#
# Author:
#    Robert Lupton, rhl@astro.princeton.edu
# Distribution:
#    You may freely distribute this file provided that this notice is included.
# You use it at your own (small) risk, and I won't be responsible if you fail
# to get tenure due to problems in your posters.
#
require "getopts.pl";

$mag = 1.0;			# amount to magnify by
$bbx0 = 1e6;			# final bounding box
$bby0 = 1e6;
$bbx1 = 0;
$bby1 = 0;

$rf = $gf = $bf = 0.0;		# default foreground colour

if(!&Getopts('b:t:f:hm:')) {
   &syntax;
   exit 1;
}

if($opt_h) {
   &syntax;
   exit 1;
}

if($opt_b) {
   $big = 10000;
   $bkgd = "$opt_b setrgbcolor
 -$big -$big moveto -$big $big lineto $big $big lineto $big -$big lineto
fill\n";
}

if($opt_f) {
   if(split(" ",$opt_f) != 3) {
      warn "Please specify exactly three numbers with -f, e.g. -f \"0 0 0\"\n";
   } else {
      ($rf, $gf, $bf) = split(" ",$opt_f);
   }
}

if($opt_m) {
   $mag = $opt_m;
}

print <<EOF;
%!PS-Adobe-3.0 EPSF-3.0
%%Creator: Mirage + include
%%BoundingBox: (atend)
%%Pages: 1 1
%%DocumentFonts: (atend)
%%EndComments
%%BeginProlog
10 dict begin
    
/BeginEPSF {
   /b4_Inc_state save def		% Save state for cleanup
   /dict_count countdictstack def	% Count objects on dict stack
   /op_count count 1 sub def		% Count objects on operand stack
   /epsf_transfer { currenttransfer } bind def	% initial transfer function
   userdict begin			% Push userdict on dict stack
   /showpage { } def			% Redefine showpage
   0 setgray 0 setlinecap		% Prepare graphics state
   1 setlinewidth 0 setlinejoin
   10 setmiterlimit [ ] 0 setdash newpath
   /languagelevel where	{		% If level not equal to 1 then
      pop languagelevel			% set strokeadjust and
      1 ne {				% overprint to their defaults
         false setstrokeadjust false setoverprint
      } if
   } if
} bind def

/EndEPSF {
   count op_count sub {pop} repeat	% Clean up stacks
   countdictstack dict_count sub {end} repeat
   epsf_transfer settransfer		% initial transfer function
   b4_Inc_state restore
} bind def

$bkgd
%%EndProlog
%%Page: 1 1
EOF

while(<>) {
    chop;
    
    if($_ eq "" || /^#/) {
       next;
    }
    
    ($file, $xoff, $yoff, $xsize, $ysize, $r, $g, $b) = split;
    if($mag) {
       $xoff *= $mag;
       $yoff *= $mag;
       $xsize *= $mag;
       $ysize *= $mag;
    }

    &do_file($file, $xoff, $yoff, $xsize, $ysize, $r, $g, $b);
}

if($bbx0 >= 1e6) { $bbx0 = 0; }	# we failed to set it
if($bby0 >= 1e6) { $bby0 = 0; }	# we failed to set it

foreach $f (keys %fonts) {
   $docfonts .= " $f";
}

print <<EOF;
end
showpage
%%PageTrailer
%%Trailer
%%BoundingBox: $bbx0 $bby0 $bbx1 $bby1
%%DocumentFonts:$docfonts
%%EOF
EOF

###############################################################################

sub do_file
{
    local($file,$xoff,$yoff,$xsize,$ysize,$r,$g,$b) = @_;

    $xoff *= 72;		# convert to PS points
    $yoff *= 72;
    $xsize *= 72;
    $ysize *= 72;

    if($r || $b || $g) {
       if($r eq "") { $r = 0.0; }
       if($g eq "") { $g = 0.0; }
       if($b eq "") { $b = 0.0; }
    } else {
       $r = $rf; $g = $gf; $b = $bf; # default foreground
    }

    if(open(EPSF,"$file") == 0) {
	warn "Cannot open $file\n";
	return;
    }

    print "BeginEPSF\n";
    print "%%BeginDocument:\n";
    while(<EPSF>) {
        s/^%!/%*!/;
        s/^%%/%*%/;
	if(/^%\*%BoundingBox\s*:\s*(-?\d+)\s+(-?\d+)\s+(-?\d+)\s+(-?\d+)/) {
	    print;
	    $bx0 = $1;		# origin of BBox
	    $by0 = $2;
	    $bxsize = $3 - $1;	# sizes of bounding box
	    $bysize = $4 - $2;
	    if($bxsize == 0 || $bysize == 0) {
		warn "Invalid BBox for $file: $_";
		last;
	    }
	    if($ysize == 0) {
	       $ysize = $xsize*$bysize/$bxsize;
	    }

	    if($xsize == 0 && $ysize == 0) {
	       $xscale = $yscale = $mag;
	    } elsif($xsize == 0) {
	       $yscale = $ysize/$bysize;
	       $xscale = $yscale;
	    } elsif($ysize == 0) {
	       $xscale = $xsize/$bxsize;
	       $yscale = $xscale;
	    } else {
	       $xscale = $xsize/$bxsize;
	       $yscale = $ysize/$bysize;
	    }
	    $xsize = $bxsize*$xscale;
	    $ysize = $bysize*$yscale;

	    if($xoff < $bbx0) { $bbx0 = $xoff; }
	    if($yoff - $ysize < $bby0) { $bby0 = $yoff - $ysize; }
	    if($xoff + $xsize > $bbx1) { $bbx1 = $xoff + $xsize; }
	    if($yoff > $bby1) { $bby1 = $yoff; }

	    printf "%d %d translate\n",$xoff,$yoff - $ysize;
	    printf "%g %g scale\n",$xscale,$yscale;
	    printf "%g %g translate\n",-$bx0,-$by0;
	    printf "%g %g %g setrgbcolor\n",$r, $g, $b;
	 } elsif(/^%\*%DocumentFonts: (\w+.*)/) {
	    $list = $1;
	    print;
	    foreach $f (split(" ",$list)) {
	       $fonts{$f} = 1;
	    }
	} else {
	    print;
	}
    }
    print "%%EndDocument:\n";
    print "EndEPSF\n";
    close(EPSF);
}


###############################################################################

sub syntax
{
   print <<"EOT";
Include a number of epsf files, with origins specified wrt the bottom
left, and measured in inches. Optionally, specify the x or y size too,
and the colour.

For example, if the file assemble.in looks like:
	#
	# Files to be put together into a postscript page
	#
	#file xoff yoff [xsize [ysize]]	[r [g [b]]  (dimensions in inches)
	foo.ps 1 1 0 .5
	bar.ps 1.5 2 2 2  1 .5 0
the command
	assemble assemble.in | lpr
will put file foo.ps at origin (1,1), with a height of 0.5", and its proper
aspect ration, and bar.ps at (1.5,2) with both width and height 2"; bar.ps
will be in orange.

If r,g, or b is specified, it's the intensity of red, blue, or green to be
used for that file, with "1.0 1.0 1.0" being white, and "1.0 0.0 0.0", red;
the default for r, b, and b is 0.0 (i.e. black) unless set with the -f option. 

Usage:
    assemble [-b "r g b"] [-f "r g b"] [-m #] file.in
Options:
        -h          Print this message
        -b "r g b"  Make the background color "r g b" (e.g. 0 0 0 is black,
                    ".9 .9 .9" is grey. Default is "1 1 1" (white)
        -f "r g b"  Make the default color "r g b"; default is "0 0 0" (black)
	-m #	    Apply a magnification of # to all numbers in file.in
EOT
}
