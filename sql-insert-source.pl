#!/usr/local/bin/perl -w

use DBI;
use DBD::mysql;
use XML::XPath;

$dbh = DBI->connect("dbi:mysql:anchors:rhodes","anchors","password");

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

#$data_root="/data/ANCHORS/YAXX/$obs_dir/Data/obs$data_dir";
#$xml_obs="/data/ANCHORS/YAXX/$obs_dir/$data_dir\.xml";
$data_root="/proj/web-cxc-dmz/htdocs/ANCHORS/$obs_dir";
$xml_obs="$data_root\/obs.xml";
(-s $xml_obs) || die "ABORT. $xml_obs does not exist or is size 0.\n";

#  read xml data
my $xp = XML::XPath->new(filename => $xml_obs);
my @obs_xp = $xp->find('//OBS')->get_nodelist;
my $tar_name = $obs_xp[0]->find('NAME')->string_value;
my $obsid = $obs_xp[0]->find('OBSID')->string_value;
my $obsdate = $obs_xp[0]->find('DATE')->string_value;
my $exptime = $obs_xp[0]->find('EXPTIME')->string_value;
my $chips = $obs_xp[0]->find('INST')->string_value;
my $aimp = $obs_xp[0]->find('AIMPOINT')->string_value;
my @aimp = split(/[(,)]/,$aimp);
my $aim_ra = $aimp[1];
my $aim_decl = $aimp[2];
print "$obsdate $chips $aim_ra $aim_decl\n";

# look up target_id
#  see if target already exists
#$tar_sth = $dbh->prepare("select ifnull(target_id from target where target_name = '$tar_name',ifnull(max(target_id)+1,1) from target)");
$tar_sth = $dbh->prepare("select target_id from target where target_name = '$tar_name'");
$tar_sth->execute;
my $target_id = $tar_sth->fetchrow_array;
$tar_sth->finish;
if (! $target_id) {
  $tar_sth = $dbh->prepare("select ifnull(max(target_id)+1,1) from target");
  $tar_sth->execute;
  $target_id = $tar_sth->fetchrow_array;
  $tar_sth->finish;
#if ($target_id == $target_id_chk) { # insert new target
  $tar_sth = $dbh->prepare("insert into target (target_id,target_name) values ($target_id,'$tar_name')");
  $tar_sth->execute;
  $tar_sth->finish;
}
  
# populate obsid table
$obs_sth = $dbh->prepare("select ifnull(max(obs_obi_id)+1,1) from obsid");
$obs_sth->execute;
my $obs_obi_id = $obs_sth->fetchrow_array;
$obs_sth->finish;
$obs_sth = $dbh->prepare("insert into obsid (obs_obi_id,target_id,obsid,obsdate,exptime,chips,aim_ra,aim_decl) values ($obs_obi_id,$target_id,$obsid,'$obsdate',$exptime,'$chips',$aim_ra,$aim_decl)");
$obs_sth->execute;
$obs_sth->finish;

open(IN,"<$ARGV[0]") || die "Input file $ARGV[0] not found.\n";
$inline=<IN>; # skip first 2 header lines
$inline=<IN>; # skip first 2 header lines
while ($inline=<IN>) {
  chomp $inline;
  @line=split(/\s+/,$inline);

  #@src_str=split("_",$line[0]);
  #$src=$src_str[1];
  #$src_root="$data_root/src$src";
  #$xml_file="$src_root/src$src.xml";

  $src_root="$data_root/$line[1]";
  $xml_file="$src_root/src.xml";

  $xp = XML::XPath->new(filename => $xml_file);

  $srci_sth = $dbh->prepare("select ifnull(max(source_id)+1,1) from source");
  $src_sth = $dbh->prepare("insert into source (source_id,obs_obi_id,ra,decl,raw_counts,net_counts,region,bkgregion,off_ax,ccd_id) values (?,$obs_obi_id,?,?,?,?,?,?,?,?)");

  foreach my $sources ($xp->find('//SOURCE')->get_nodelist){
    $ra   = $sources->find('RA')->string_value;
    $dec  = $sources->find('DEC')->string_value;
    $cnts = $sources->find('CNTS')->string_value;
    $net_cnts = $sources->find('NET_CNTS')->string_value;
    $off_ax = $sources->find('OFF_AX')->string_value;
    $ccd_id = $sources->find('CCD_ID')->string_value;
    open(REG,"<$src_root/src.reg") || print "no source reg found.\n";
    $region=<REG>;
    chomp $region;
    close REG;
    open(BKG,"<$src_root/bkg.reg") || print "no bkg reg found.\n";
    $bkgregion=<BKG>;
    chomp $bkgregion;
    close BKG;
    $srci_sth->execute;
    $source_id = $srci_sth->fetchrow_array;
    $src_sth->execute($source_id,$ra,$dec,$cnts,$net_cnts,$region,$bkgregion,$off_ax,$ccd_id) || die("MySQL query error: ".$DBI::errstr."\n");

    $modi_sth = $dbh->prepare("select ifnull(max(model_id)+1,1) from model");
    $mod_sth = $dbh->prepare("insert into model (model_id,source_id,model,n_h,n_h_error,kt,kt_error,kt2,kt2_error,abundance,abundance_error,chi2,dof,abs_flux,kt_flux,kt2_flux) values (?,$source_id,?,?,?,?,?,?,?,?,?,?,?,?,?,?)");

    foreach my $models ($sources->find('.//MODEL')->get_nodelist){
    #foreach my $models ($sources->find('/SPECTRA/MODEL')->get_nodelist){
      $mname= $models->find('@name');
      $nh   = $models->find('NH');
      $nh_error   = $models->find('NH_ERR');
      $kt   = $models->find('KT');
      $kt_error   = $models->find('KT_ERR');
      $kt2   = $models->find('KT2');
      $kt2_error   = $models->find('KT2_ERR');
      $abundance   = $models->find('ABUND');
      $abundance_error   = $models->find('ABUND_ERR');
      $chi2  = $models->find('CHI');
      $dof  = $models->find('DOF');
      $abs_flux  = $models->find('FLUX');
      $kt_flux  = $models->find('KT_FLUX');
      $kt2_flux  = $models->find('KT2_FLUX');
      $modi_sth->execute;
      $model_id = $modi_sth->fetchrow_array;
      $mod_sth->execute($model_id,$mname,$nh,$nh_error,$kt,$kt_error,$kt2,$kt2_error,$abundance,$abundance_error,$chi2,$dof,$abs_flux,$kt_flux,$kt2_flux) || die("MySQL query error: ".$DBI::errstr."\n");
    } #foreach my $models ($xp->find('.//MODEL')->get_nodelist){

    # ingest bblocks
    $bbi_sth = $dbh->prepare("select ifnull(max(bb_id)+1,1) from bblocks");
    $bb_sth = $dbh->prepare("insert into bblocks (bb_id,source_id,n_bblocks,confidence) values (?,$source_id,?,?)");

    foreach my $bblock ($bblocks->find('.//BBLOCKS_SIG')->get_nodelist){
      $bbi_sth->execute;
      $bb_id = $bbi_sth->fetchrow_array;

      $bbni_sth = $dbh->prepare("select ifnull(max(bbn_id)+1,1) from bblocks_n");
      $bbn_sth = $dbh->prepare("insert into bblocks_n (bbn_id,bb_id,tstart,tstop,rate,rate_err) values (?,$bb_id,?,?,?,?)");
      $n_bblocks=0;
      $bb_tstart=0;
      $bb_tstop=0;
      foreach my $nbblock ($nbblocks->find('$bblock/BBLOCKS_N')->get_nodelist){
        $nbblocks++;
        $bb_tstop= $nbblock->find('BBLOCKS_DT')+$bb_stop;
        $bb_rate= $nbblock->find('BBLOCKS_RATE');
        $bb_err= $nbblock->find('BBLOCKS_ERR');
        $bbni_sth->execute;
        $bbn_id = $bbni_sth->fetchrow_array;
        $bbn_sth->execute($bbn_id,$bb_tstart,$bb_tstop,$bb_rate,$bb_err) || die("MySQL query error: ".$DBI::errstr."\n");
        $bb_tstart=$bb_tstop;
      } # foreach my $nbblock ($nbblocks->find('$bblock/BBLOCKS_N')->get_nodelist){

      $bb_conf= $bblock->find('@confidence');
      $bb_sth->execute($bb_id,$n_bblocks,$bb_conf) || die("MySQL query error: ".$DBI::errstr."\n");
    } # foreach my $bblock ($bblocks->find('.//BBLOCKS_SIG')->get_nodelist){

    $modi_sth->finish;
    $mod_sth->finish;
    $bbi_sth->finish;
    $bb_sth->finish;
    $bbni_sth->finish;
    $bbn_sth->finish;

  } #foreach my $sources ($xp->find('//SOURCE')->get_nodelist){
  $srci_sth->finish;
  $src_sth->finish;
} # while ($inline=<IN>) {
#
#for my $record (keys %csv_values)
#{
#    my %values = %{$csv_values{$record}};
#    $src_sth->execute;
#    $values{source_id} = $src_sth->fetchrow_array;
#
#    @ra=split(/:/,$values{RA});
#    $ra=360.*$ra[0]/24.+$ra[1]/60.+$ra[2]/3600.;
#    @dec=split(/:/,$values{DEC});
#    if ($dec[0] >= 0) { $dec=$dec[0]+$dec[1]/60+$dec[2]/3600.;}
#    if ($dec[0] < 0) { $dec=$dec[0]-$dec[1]/60-$dec[2]/3600.;}
#
#    $sth->execute($values{source_id},$ra,$dec,$values{RAW_CNTS},$values{NET_CNTS}) || die("MySQL query error: ".$DBI::errstr."\n");
#
#    print "insert source id $values{source_id}\n";
#}
#
#$sth->finish;
#$src_sth->finish;

$dbh->disconnect;

exit 0;
#
