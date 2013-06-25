#! /usr/bin/perl
# run 2mass matching script
# - get ra_nom, dec_nom from evt file
#   (must be run after yaxx, at least after yaxx is started
#    because we'll look at src1/acis_evt2.fits)
# - get 2mass source list 
# - do matching and outputs with idl script

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

$obs_root="/data/ANCHORS/YAXX/$obs_dir";
$data_root="$obs_root/Data/obs$data_dir";
@ra_lst=split(/\s+/,`dmlist $data_root/src1/acis_evt2.fits header | grep RA_NOM`);
@dec_lst=split(/\s+/,`dmlist $data_root/src1/acis_evt2.fits header | grep DEC_NOM`);
$ra_nom=$ra_lst[2];
$dec_nom=$dec_lst[2];

print "$ra_nom $dec_nom\n";

# collect 2mass list
# put 2mass list at "/data/ANCHORS/YAXX/$obs_dir/fp_2mass.tbl";
#`/usr/bin/wget "http://irsa.ipac.caltech.edu/cgi-bin/Oasis/CatSearch/nph-catsearch?server=%40rmt_stone&database=fp_2mass&catalog=fp_psc&sql=select+ra%2C+dec%2C+j_m%2Cj_cmsig%2Cj_msigcom%2Ch_m%2Ch_cmsig%2Ch_msigcom%2Ck_m%2Ck_cmsig%2Ck_msigcom%2Cph_qual%2Crd_flg%2Cbl_flg%2Ccc_flg%2Cgal_contam%2Cmp_flg%2Cprox%2Cpxpa+from+fp_psc&within=12+arcmin&objstr=$ra_nom+$dec_nom" -O $obs_root/fp_2mass_tmp.tbl`;
`/usr/bin/wget "http://irsa.ipac.caltech.edu/cgi-bin/Oasis/CatSearch/nph-catsearch?server=%40rmt_dbms20&database=fp_2mass&catalog=fp_psc&sql=select+ra%2C+dec%2C+j_m%2Cj_cmsig%2Cj_msigcom%2Ch_m%2Ch_cmsig%2Ch_msigcom%2Ck_m%2Ck_cmsig%2Ck_msigcom%2Cph_qual%2Crd_flg%2Cbl_flg%2Ccc_flg%2Cgal_contam%2Cmp_flg%2Cprox%2Cpxpa+from+fp_psc&within=12+arcmin&objstr=$ra_nom+$dec_nom" -O $obs_root/fp_2mass_tmp.tbl`;

unlink "$obs_root/fp_2mass.tbl";
`sed -e 's/null/9999/g' $obs_root/fp_2mass_tmp.tbl > $obs_root/fp_2mass.tbl`;

unlink "$obs_root/fp_2mass_tmp.tbl";

# call idl matching prog
$tmpfile="tmp_2mass";
open(IDL,">$tmpfile\.pro");
#print IDL "match_obsid,\'$ARGV[0]\', \'$data_dir\', $ra_nom, $dec_nom\n";
print IDL "match_obsid,\'$data_dir\', $ra_nom, $dec_nom\n";
print IDL "exit\n";
close IDL;
`idl $tmpfile`;
unlink "$tmpfile\.pro";

# end
