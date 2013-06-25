#!/usr/local/bin/perl -w
#* Standard ANCHORS Header ##############################################
#
#* Copyright (c) 2007, Smithsonian Astrophysical Observatory
#  You may do anything you like with this file except remove this
#  copyright.
#
#* FILE NAME: stat_plot
#
#* DEVELOPMENT: ANCHORS
#
#* DESCRIPTION: analysis script to compare ANCHORS processing to the COUP
#               dataset for clusters M17 and Cep B
#
#
#* REVISION HISTORY:
#  - v1.0 01/18/07 by Owen Westbrook
#
#########################################################################

use DBI;
use DBD::mysql;

my $database = 'anchors';
my $host = 'rhodes';

#!### connect to the anchors database ###
#$dbh = DBI->connect("dbi:mysql:$database:$host","$database","password") || die $DBI::errstr;
$dbh = DBI->connect("dbi:mysql:anchors:rhodes","anchors","password") || die $DBI::errstr;

#!### prepare and execute the query ### 
$sth = $dbh->prepare("select t.target_name,o.obsid,s.source_id,s.net_counts,m.kt,m.kt2,m.model from obsid as o, target as t, source as s, model as m where o.obsid='972' and o.target_id=t.target_id and s.obs_obi_id=o.obs_obi_id and s.source_id=m.source_id order by s.net_counts");
$sth->execute() || die("MySQL query error: ".$DBI::errstr."\n");

#!### retrieve each row from the query results ###
while ($cts_record = $sth->fetchrow_array) {
  print "$cts_record[0]\n";
}


$dbh->disconnect;

exit 0;
