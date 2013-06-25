#!/usr/local/bin/perl5
#!### require the needed Perl distributed packages ###
use Getopt::Long;

#!### require the needed custom packages ###
use XDB qw(time_check);
use FileSysProc qw(ops_open);
use CIAO;
use OutputText;
use Parameter;
use lib '/proj/axaf/simul/lib/perl';
#use GrabEnv qw(grabenv grabenv_File grabenv_Expect diffenv envstr);
#use IO::Tty;
use Expect;
use CXC::Envs;
use CXC::Archive;

my $yaxx = $ENV{yaxx};
use lib "${yaxx}"."/lib";
my $obsid = "02337";
my $nd = "${yaxx}"."/"."${obsid}";
print "$nd\n";
chdir $nd;
my $pwd = `pwd`;
print "$pwd";

%attr = (
	 User       => 'anchors',
	 Directory  => $nd,
	 ifGuestUser => 'yes',
	);
my $arc = new CXC::Archive \%attr;

#my %req1 = (
#	    dataset     => 'flight',
#	    detector    => 'acis',
#	    level       => 2,
#	    filetype    => 'evt2',
#	    obsid       => '2337',
#	   );
#my %req2 = (
#	    dataset     => 'flight',
#	    detector    => 'pcad',
#	    subdetector => 'aca',
#	    level       => 1,
#	    filetype    => 'aspsol',
#	    obsid       => '2337',
#	   );
my %req1 = (
	    dataset     => 'flight',
	    detector    => 'acis',
	    level       => 1,
	    obsid       => 2337,
	   );

#foreach (sort keys %ENV) {
#  print "$_  =  $ENV{$_}\n";
#}

$files1 = $arc->browse(\%req1);
$files1 = $arc->retrieve(\%req1);
#$files2 = $arc->browse(\%req2);
#$files2 = $arc->retrieve(\%req2);

exit 0;
