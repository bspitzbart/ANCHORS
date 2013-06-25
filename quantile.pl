#!/usr/bin/perl -w
# finding quantiles

# JaeSub Hong, 2003-2005, version 1.5
# Please report any problem or suggestion at jaesub@head.cfa.harvard.edu
# 
# Calculate quantiles from a distribution
# Refer to 
#	J. Hong, E.M. Schlegel & J.E. Grindlay, 
#	2004 ApJ 614 p508 and references therein
# 
# usage
#	quantile.pl -frac frac1,frac2, -src src_file -range lower,upper 
#		-bkg bkg_file -ratio ratio
# examples
#	quantile.pl -src src.txt -range 0.3:8.0
#	quantile.pl -src src.txt -range 0.3:8.0 -bkg bkg.txt -ratio 0.2
#
# required input:
#	-frac: list of quantile fractions 
#		default: 0.25,0.33,0.5,0.67,0.75
#	-src : src file containing the list of values in the source region 
#		(e.g. energies of photons in the source region separated
#		by space, tab, or return)
#	-range :  the full range of values
# required input for bkgnd subtraction:
#	-bkg : bkg file containing the list of valuess in the bkgnd region 
#		(e.g. energies of photons in the bkgnd region)
#	-ratio : ration of the source to bkgnd region
# optional input
#	-nip : number of interplation points for bkgnd subtraction
#		default 1000
#	-fixerror : when the error estimation fails, it normally returns
#		-1 for the error, but we can set the error based on 
#		the range of values.
#		default : no
#	-nosort: src and bkg will be sorted in ascending order, but
#		they are already sorted, you can skip the sorting procedure
#
# output
#	print out fraction, quantile (Ex%), errors.
#
# the next version will include Harrell-Davis tech

#----------------------------------------------------------------------
# get the parameter files from command line
use Getopt::Long;
GetOptions(
	"frac=s"	=> \$frac,
	"src=s"		=> \$src,
	"bkg=s"		=> \$bkg,
	"ratio=s"	=> \$ratio,
	"range=s"	=> \$range,
	"nip=i"		=> \$nip,
	"nosort=s"	=> \$nosort,
	"fixerror" 	=> \$fixerror,
	"help" 		=> \$help,
	"debug:i" 	=> \$debug);

$debug = 0 unless defined $debug;

if (defined $help
	|| !defined $src
	|| !defined $range
	) {
	($usage = <<"	EOFHELP" ) =~ s/^\t\t//gm;
		Find quantiles for given fractions
		usage: $0  [-help] [-debug [X]] 
			-src file
			-range xx.x:yy.y
			[-frac 0.xx,0.yy,...]
			[-bkg file] [-ratio x.x]
			[-Nip xxxx]
		options
			-help     print this message
			-debug    set the level of debug
			-frac     interested fraction, def 0.25,0.33,0.5,0.67,0.75
			-src      src file
			-bkg      bkg file
			-ratio    ratio of src/bkg region, def 1.0
			-range 	  range of the values
			-nosort   no need to sort values if they are alresy sorted
			-nip      Number of energy point for interpolation, def 1000
			-fixerror fix error
	EOFHELP
	print $usage;
	exit;
}

$frac	= "0.25,0.33,0.5,0.67,0.75"  unless defined $frac;
@frac	= split/,/, $frac;
$ratio	= 1.0	unless defined $ratio;
$nip	= 1000 	unless defined $nip;

$maxit 	= 100;
$eps 	= 3.0e-7;
$fpmin 	= 1.0e-30;

#----------------------------------------------------------------------
($ll, $ul) = split/[:,]/, $range;
$rl = $ul-$ll;

open(SRC, "< $src") || die "can't open $src\n";
@src = <SRC>;
close(SRC);
foreach (@src) {chomp; s/\s+//mg; };
@src = sort {$a <=> $b} @src unless defined $nosort;
$n_src= $#src+1;
$n_bkg= 0;
$n_net = $n_src;

$src_only="no";
if (defined $bkg) {
	open(BKG, "< $bkg") || die "can't open $bkg\n";
	@bkg = <BKG>;
	close(BKG);
	foreach (@bkg) {chomp; s/\s+//mg;};
	$src_only = "yes" if $#bkg < 0;
} else { $src_only="yes";}

if ($src_only eq "yes") {
	@qt = order_stat(\@frac,\@src,$ll, $ul);
	@err_qt = error_mj(\@frac,\@src,$ll, $ul);
	@err_qt  = fix_error(\@qt, \@err_qt, $ll, $ul) if defined $fixerror;
	result();
	exit;
}
@bkg = sort {$a <=> $b} @bkg unless defined $nosort;

#$n_src= $#src+1;
$n_bkg= $#bkg+1;

$n_net = $n_src -$ratio * $n_bkg;

if ($n_net lt 1.0) {
	for ($i=0;$i<=$#frac;$i++) {
		push(@qt,$frac[$i]*$rl+$ll);
		push(@err_qt,-1.);
	}
	@err_qt  = fix_error(\@qt, \@err_qt, $ll, $ul) if defined $fixerror;
	result();
	exit;
}

for ($i=0;$i<$nip;$i++) {
	$inc = ($i+0.5)/$nip;
	push(@ifrac, $inc);
	push(@iE, $inc*$rl+$ll);
	push(@nsrc, $inc*$n_src);
	push(@nbkg, $inc*$n_bkg);
}

@iqt_src = order_stat(\@ifrac, \@src, $ll, $ul);
@iqt_bkg = order_stat(\@ifrac, \@bkg, $ll, $ul);

@ic_src=interpol(\@nsrc, \@iqt_src, \@iE);
@ic_bkg=interpol(\@nbkg, \@iqt_bkg, \@iE);

# forward
foreach (@ic_src){
	$_ = 0.0  if $_ < 0.0;
	$_ = $n_src  if $_ > $n_src;
}
foreach (@ic_bkg){
	$_ = 0.0  if $_ < 0.0;
	$_ = $n_bkg  if $_ > $n_bkg;
}
$cur = $ic_src[0] - $ic_bkg[0] *$ratio;
$cur = 0.0  if $cur < 0.0;
$cur = $n_net  if $cur > $n_net;
push(@ic_net, $cur);
push(@ic_net_, 0.0);
for ($i=1;$i<$nip;$i++) {
	$cur = $ic_src[$i] - $ic_bkg[$i] * $ratio;
	$cur = $n_net  if $cur > $n_net;
	$cur = $ic_net[$i-1] if $cur < $ic_net[$i-1];
	push(@ic_net, $cur);
	push(@ic_net_, 0.0);
}

# backward
foreach (@ic_src){ $_ = $n_src - $_;}
foreach (@ic_bkg){ $_ = $n_bkg - $_;}
$cur = $ic_src[$nip-1] - $ic_bkg[$nip-1] * $ratio;
$cur = 0.0  if $cur < 0.0;
$cur = $n_net  if $cur > $n_net;
$ic_net_[$nip-1]=$cur;
for ($i=$nip-2;$i>=0;$i--) {
	$cur = $ic_src[$i] - $ic_bkg[$i] * $ratio;
	$cur = $n_net  if $cur > $n_net;
	$cur = $ic_net_[$i+1] if $cur < $ic_net_[$i+1];
	$ic_net_[$i]= $cur;
}

# average forward and backword
for ($i=0;$i<$nip;$i++) {
	push(@net_frac, ($ic_net[$i]-$ic_net_[$i]+$n_net)/2./$n_net);
}
@qt = interpol(\@iE, \@net_frac, \@frac);

# regenerate photons
$n_net_ = sprintf("%d", $n_net+0.5);
for ($i=0; $i<$n_net_;$i++) { push(@tqt, ($i*2+1.)/$n_net_/2.); }
@ip_src_ph = interpol(\@iE, \@net_frac, \@tqt);

@err_qt = error_mj(\@frac, \@ip_src_ph, $ll, $ul);
@err_qt  = fix_error(\@qt, \@err_qt, $ll, $ul) if defined $fixerror;

result();

exit;
#----------------------------------------------------------------------

sub result{
	print "range  $ll $ul\n";
	print "source $n_src\n";
	print "bkgnd  $n_bkg\n";
	print "net    $n_net\n";
	print "ratio  $ratio\n";
	print "fraction quantile(Ex%)  error\n";
	for ($i=0;$i<=$#frac;$i++) {
		printf(" %.3f   %.3e %.3e\n",$frac[$i],$qt[$i],$err_qt[$i]);
	}
}

#----------------------------------------------------------------------
# The followings are based on the routines: betacf.c, betai.c and
#              gammln.c described in section 6.2 of Numerical Recipes,
#              The Art of Scientific Computing (Second Edition), and is
#              used by permission.
sub gammln{
	@cof = (76.18009172947146,-86.50532032941677,
		24.01409824083091,-1.231739572450155,
		0.1208650973866179e-2,-0.5395239384953e-5);

	my ($y) = @_;
	my $x = $y;
	my $tmp=$x+5.5;
	$tmp -= ($x+0.5)*log($tmp);
	my $ser=1.000000000190015;
	for ($j=0;$j<=5;$j++) { $ser += $cof[$j]/++$y;};
 	return -$tmp+log(2.5066282746310005*$ser/$x);
}

sub betacf{
	my ($a, $b, $x) = @_;

	my $qab=$a+$b; 
	my $qap=$a+1.0;
	my $qam=$a-1.0;

	my @ans=();
	my $c=1.0; 
	my $d=1.0-$qab*$x/$qap;

	if (abs($d) < $fpmin) {$d=$fpmin;};
	$d=1.0/$d;
	my $h=$d;
	for ($m=1;$m<=$maxit;$m++) {
		$m2=2*$m;
		$aa=$m*($b-$m)*$x/(($qam+$m2)*($a+$m2));
		$d=1.0+$aa*$d; 
		if (abs($d) < $fpmin) {$d=$fpmin;};
		$c=1.0+$aa/$c;
		if (abs($c) < $fpmin) {$c=$fpmin;};
		$d=1.0/$d;
		$h *= $d*$c;
		$aa = -($a+$m)*($qab+$m)*$x/(($a+$m2)*($qap+$m2));
		$d=1.0+$aa*$d; 
		if (abs($d) < $fpmin) {$d=$fpmin;};
		$c=1.0+$aa/$c;
		if (abs($c) < $fpmin) {$c=$fpmin;};
		$d=1.0/$d;
		$del=$d*$c;
		$h *= $del;
		last if abs($del-1.0) < $eps; 
	}
	printf "ERROR: a or b too big, or MAXIT too small in betacf\n"
		if $m > $maxit;
	return $h;
}

sub betai{
	my ($a, $b, @xx) = @_;

	my @ans=();
	foreach $x (@xx) {
		printf "Bad x in routine betai\n" if $x < 0.0 || $x > 1.0 ;
		if ($x == 0.0 || $x == 1.0)  { 
			$bt=0.0;
		} else { 
			$bt=exp(gammln($a+$b)-gammln($a)-gammln($b)
				+$a*log($x)+$b*log(1.0-$x));
		};
		if ($x < ($a+1.0)/($a+$b+2.0)){ 
			push(@ans, $bt*betacf($a,$b,$x)/$a);
		} else { 
			push(@ans, 1.0-$bt*betacf($b,$a,1.0-$x)/$b);
		}
	}
	return @ans;
}

#----------------------------------------------------------------------
# simple interpolation routines

sub value_locate {
	my ($x, $nx, $ilo, $ihi) = @_;
#	$ilo = 0;
#	$ihi = @$x -1;

	return $ihi if $nx >= $x->[$ihi]; 
	return $ilo if $nx <= $x->[$ilo]; 
	# make sure $nx >= $x->[$ilo] unless $ilo==0; or use $ilo==0;

	for (;;) {
    		my $middle = int(($ilo + $ihi)/2);
    		if ($middle == $ilo) { return $ilo; }
	    	if ($nx < $x->[$middle]) { $ihi = $middle; }
	    	else { $ilo = $middle; }
  	}

}

sub interpol{
	my ($y, $x, $nx) = @_;

	my $last = @$x-1;
	my @ans =();
	foreach $nx_ ( @{$nx} ) {
		my $j = value_locate($x, $nx_, 0, $last);
		$j = $last-1 if $j >= $last;
		my $k = $j + 1;
		my $dy = ($y->[$k]-$y->[$j])/($x->[$k]-$x->[$j]);
		my $ny  = $dy*($nx_-$x->[$j]) + $y->[$j];
		push (@ans, $ny);
	}
	return @ans;
}

#----------------------------------------------------------------------
# quantile routines
sub order_stat{
	my($frac, $values, $ll, $ul) = @_;
	my @qt=();
	for (my $i=0;$i<@$values;$i++) {
		push(@qt, ($i*2.0+1.0)/2./@$values);
	}

	my @values_ = ($ll,@{$values},$ul);
	my @qt_ = (0.0,@qt,1.0);

	my @ans = interpol(\@values_,\@qt_, $frac);
	return @ans;
}

sub error_mj{
# Error estimation by Maritz-Jarrett method
	my($frac, $values, $ll, $ul) = @_;

	my @m=();
	my @a=();
	my @b=();

	my $hrange = ($ul-$ll)/2.;

	$nvalues = @$values;
	for (my $i=0;$i<@$frac;$i++) {
 		my $m_ = ($frac->[$i])*($nvalues)+0.5; #int should be gone!!!

		push(@m,$m_);
		push(@a,$m_-1.0);
  		push(@b,$nvalues-$m_);

	}

	my @i_src=();
	for ($i=0;$i<=$nvalues;$i++) {
   		push(@i_src,$i/$nvalues);
	}
  	my @values_ = (@{$values});
	my @ans=();
	for ($i=0;$i<@$frac;$i++){
		if ($a[$i] <= 0.0 || $b[$i] <= 0.0) {
			push(@ans, -1.0);
			next;
		}
		my @beta=betai($a[$i],$b[$i],@i_src);
		my ($c0, $c1, $c2) = (0.0, 0.0, 0.0);
		for (my $j=0;$j<=$#values_;$j++){
			$c0 = $values_[$j] * ($beta[$j+1] - $beta[$j]);
			$c1 += $c0;
			$c2 += $c0*$values_[$j];
		}
		$c0 = $c2-$c1*$c1;
		if ($c0 >= 0.0) {
			$c0 = sqrt($c0);
		} else {
			$c0 = -1.0;
		}
		push(@ans, $c0);
	}
	return @ans;
}


sub fix_error {
	my ($lqt, $lerr, $ll, $ul) = @_;

	my @ans=();
	for ($i=0;$i<@$lqt;$i++){
		$error = $ul - $lqt->[$i];
		$error_ = $lqt->[$i] - $ll;
		$error = $error_ if $error < $error_;
		if ($lerr->[$i] < 0.0 || $lerr->[$i] > $error) {
			push(@ans, $error);
		} else {
			push(@ans, $lerr->[$i]);
		}
	}
	return @ans;

}

