#!/usr/local/bin/perl -w

use DBI;
use DBD::mysql;

$dbh = DBI->connect("dbi:mysql:anchors:rhodes","anchors","password");

my $infile = $ARGV[0];
my $obsid = $ARGV[1];

open FILE, $infile;

$i = 0;
<FILE>; # read first row, specific to xxxx.csv
while (<FILE>)
{
   chomp $_;

   if (! $i)
   {
        s/,NH,/,BB1_NH,/;
        s/,NH_ERR,/,BB1_NH_ERR,/;
        s/,KT1,/,BB1_KT1,/;
        s/,KT1_ERR,/,BB1_KT1_ERR,/;
        s/,KT2,/,BB1_KT2,/;
        s/,KT2_ERR,/,BB1_KT2_ERR,/;
        s/,ABUND,/,BB1_ABUND,/;
        s/,ABUND_ERR,/,BB1_ABUND_ERR,/;
        s/,FLUX,/,BB1_FLUX,/;
        s/,KT1_FLUX,/,BB1_KT1_FLUX,/;
        s/,KT2_FLUX,/,BB1_KT2_FLUX,/;
        s/,CHI\^2,/,BB1_CHI2,/;
        s/,FREEDOM,/,BB1_FREEDOM,/;
        s/,NH,/,BB2_NH,/;
        s/,NH_ERR,/,BB2_NH_ERR,/;
        s/,KT1,/,BB2_KT1,/;
        s/,KT1_ERR,/,BB2_KT1_ERR,/;
        s/,KT2,/,BB2_KT2,/;
        s/,KT2_ERR,/,BB2_KT2_ERR,/;
        s/,ABUND,/,BB2_ABUND,/;
        s/,ABUND_ERR,/,BB2_ABUND_ERR,/;
        s/,FLUX,/,BB2_FLUX,/;
        s/,KT1_FLUX,/,BB2_KT1_FLUX,/;
        s/,KT2_FLUX,/,BB2_KT2_FLUX,/;
        s/,CHI\^2,/,BB2_CHI2,/;
        s/,FREEDOM,/,BB2_FREEDOM,/;
        s/,NH,/,BB3_NH,/;
        s/,NH_ERR,/,BB3_NH_ERR,/;
        s/,KT1,/,BB3_KT1,/;
        s/,KT1_ERR,/,BB3_KT1_ERR,/;
        s/,KT2,/,BB3_KT2,/;
        s/,KT2_ERR,/,BB3_KT2_ERR,/;
        s/,ABUND,/,BB3_ABUND,/;
        s/,ABUND_ERR,/,BB3_ABUND_ERR,/;
        s/,FLUX,/,BB3_FLUX,/;
        s/,KT1_FLUX,/,BB3_KT1_FLUX,/;
        s/,KT2_FLUX,/,BB3_KT2_FLUX,/;
        s/,CHI\^2,/,BB3_CHI2,/;
        s/,FREEDOM,/,BB3_FREEDOM,/;
        print "$_\n";
        my @columns = split(/,/,$_);
        @column_names = @columns;
        <FILE>;  # read units row
        $i++;
	next;
   }
   my @columns = split(/,/,$_);
   %{$csv_values{$i}} = map { $column_names[$_] => $columns[$_]; } 0 .. $#columns;
   $i++;
}

#$obs_obi_id = $ARGV[0];  # this is an integer value you have from making the parent obsids record
$obs_sth = $dbh->prepare("select ifnull(max(obs_obi_id)+1,1) from obsid_test");
$obs_sth->execute;
my $obs_obi_id = $obs_sth->fetchrow_array;
$obs_sth->finish;
$obs_sth = $dbh->prepare("insert into obsid_test (obs_obi_id,obsid) values ($obs_obi_id,$obsid)");
$obs_sth->execute;
$obs_sth->finish;

$mod_sth = $dbh->prepare("select ifnull(max(model_id)+1,1) from model_test");
$bb1_sth = $dbh->prepare("insert into model_test (model_id,source_id,model,n_h,n_h_error,kt,kt_error,chi2,dof,abs_flux,kt_flux) values (?,?,'bbrs',?,?,?,?,?,?,?,?)");
$bb2_sth = $dbh->prepare("insert into model_test (model_id,source_id,model,n_h,n_h_error,kt,kt_error,kt2,kt2_error,chi2,dof,abs_flux,kt_flux,kt2_flux) values (?,?,'bbrs2',?,?,?,?,?,?,?,?,?,?,?)");
$bb3_sth = $dbh->prepare("insert into model_test (model_id,source_id,model,n_h,n_h_error,kt,kt_error,kt2,kt2_error,chi2,dof,abs_flux,kt_flux,kt2_flux) values (?,?,'bbrs2a',?,?,?,?,?,?,?,?,?,?,?)");

for my $record (keys %csv_values)
{
    my %values = %{$csv_values{$record}};
    $mod_sth->execute;
    $values{model_id} = $mod_sth->fetchrow_array;

    @ra=split(/:/,$values{RA});
    $ra=360.*$ra[0]/24.+$ra[1]/60.+$ra[2]/3600.;
    @dec=split(/:/,$values{DEC});
    if ($dec[0] >= 0) { $dec=$dec[0]+$dec[1]/60+$dec[2]/3600.;}
    if ($dec[0] < 0) { $dec=$dec[0]-$dec[1]/60-$dec[2]/3600.;}
    $ra=sprintf("%10.6f",$ra);
    $dec=sprintf("%10.6f",$dec);
    $find_sth = $dbh->prepare("select source_id from source_test where source_test.ra=$ra and source_test.decl=$dec");
    $find_sth->execute;
    my $source_id = $find_sth->fetchrow_array;

    $bb1_sth->execute($values{model_id},$source_id,$values{BB1_NH},$values{BB1_NH_ERR},$values{BB1_KT1},$values{BB1_KT1_ERROR},$values{BB1_CHI2},$values{BB1_FREEDOM},$values{BB1_FLUX},$values{BB1_KT1_FLUX}) || die("MySQL query error: ".$DBI::errstr."\n");
    $mod_sth->execute;
    $values{model_id} = $mod_sth->fetchrow_array;
    $bb2_sth->execute($values{model_id},$source_id,$values{BB2_NH},$values{BB2_NH_ERR},$values{BB2_KT1},$values{BB2_KT1_ERROR},$values{BB2_KT2},$values{BB2_KT2_ERROR},$values{BB2_CHI2},$values{BB2_FREEDOM},$values{BB2_FLUX},$values{BB2_KT1_FLUX},$values{BB2_KT2_FLUX}) || die("MySQL query error: ".$DBI::errstr."\n");
    $mod_sth->execute;
    $values{model_id} = $mod_sth->fetchrow_array;
    $bb3_sth->execute($values{model_id},$source_id,$values{BB3_NH},$values{BB3_NH_ERR},$values{BB3_KT1},$values{BB3_KT1_ERROR},$values{BB3_KT2},$values{BB3_KT2_ERROR},$values{BB3_CHI2},$values{BB3_FREEDOM},$values{BB3_FLUX},$values{BB3_KT1_FLUX},$values{BB3_KT2_FLUX}) || die("MySQL query error: ".$DBI::errstr."\n");

    print "insert source id $source_id\n";
}

$mod_sth->finish;
$find_sth->finish;
$bb1_sth->finish;
$bb2_sth->finish;
$bb3_sth->finish;
$dbh->disconnect;

exit 0;
