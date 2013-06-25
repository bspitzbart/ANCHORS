#!/proj/axaf/sun4u-SunOS-5/bin/perl
#-------------------------------
#[ANCHORS processing version 2.1.1.1 (source detection modified)]
#
#
#
#
#-----------------------
use Getopt::Std;
use Getopt::Long;
#use Env qw(HOST); #only want the HOST variable

#ssh rhodes -l anchors
# [sets anchors environment, mst_envs.tcsh, ciao, reset_param;
#   changes to $yaxx dir]

#GetOptions( 's=s' => \$server); #to be passed to acisparams.pl

$argc = @ARGV;
$argc >= 1  or die "USAGE: anchors_set_dirs.pl  <obsid to process>\n";

#directory definitions
$yaxx_dir=</data/ANCHORS/YAXX>;
$obsid=@ARGV[0];
# THE wave directory requires 5 digits
$obsid2=$obsid;
while (length ($obsid2) < 5){
   $obsid2="0${obsid2}";
}

$obsdir = "$yaxx_dir/$obsid2";
$obsdirp = "${obsdir}/param";
$obsdatadir="${obsdir}/Data";
$obsdir2="${obsdatadir}/obs${obsid}";
$obsdir2p="${obsdir2}/param";
$obsdir2a="${obsdir2}/ApertureImages";
$wavedir="$yaxx_dir/WavDetect_RBA/${obsid2}";
$waveband="${wavedir}/0.3-8.0";
$wavebandp="${waveband}/param";

#----------------------------------------
#create directories, change to directory
#----------------------------------------
unless (-d $obsdir){
  mkdir($obsdir,0772) or die "Error:Couldn't make directory:${obsdir}\n";
}
unless (-d $obsdirp){
  mkdir($obsdirp,0772) or die "Error:Couldn't make directory:${obsdirp}\n";
}
unless (-d $obsdatadir){
  mkdir($obsdatadir,0772) or die "Error:Couldn't make directory:${obsdatadir}\n";
}
unless (-d $obsdir2){
  mkdir($obsdir2,0772) or die "Error:Couldn't make directory:${obsdir2}\n";
}
unless (-d $obsdir2p){
  mkdir($obsdir2p,0772) or die "Error:Couldn't make directory:${obsdir2p}\n";
}
unless (-d $obsdir2a){
  mkdir($obsdir2a,0772) or die "Error:Couldn't make directory:${obsdir2a}\n";
}
unless (-d $wavedir){
  mkdir($wavedir,0772) or die "Error: Couldn't make directory:${wavedir}\n";
}
unless (-d $waveband){
  mkdir($waveband,0772) or die "Error: Couldn't make directory:${waveband}\n";
}
unless (-d $wavebandp){
  mkdir($wavebandp,0772) or die "Error: Couldn't make directory:${wavebandp}\n";
}
print "$obsdir2";
exit;
