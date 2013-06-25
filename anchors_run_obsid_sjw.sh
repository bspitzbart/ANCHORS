#! /usr/bin/sh -x
###############################################################################
#ANCHORS pipeline by obsid
#
#
#Nancy Adams-Wolk 1/13/06
#
###############################################################################
 if [ $# -lt 1 ]
    then
        echo "useage: $0 <obsid>"
        exit 1
 fi

echo $0 $1
#----------------------------------------
#want obsid in both 4 and 5 digit format
#----------------------------------------
    obsid=$1
    obsid2=$obsid
    foo=`echo $obsid2 | wc -c`

while [ $foo -le 5 ]
    do
       obsid2="0$obsid2"
       foo=`echo $obsid2 | wc -c`
done
#----------------------------------------
#confirm this is the anchors account
#----------------------------------------
id_anchors=`id -a anchors | cut -f2 -d= | cut -f1 -d'('`
id_user=`id | cut -f2 -d= | cut -f1 -d'('`
username=`id | cut -f2 -d= | cut -f2 -d'(' | cut -f1 -d')'`
if [ $id_anchors != $id_user ]
   then
    echo "ERROR: Please log in as anchors. You are logged in as $username"
    exit 1
fi
#------------------------
#confirm ascds is set
#------------------------
env | grep ASCDS_VERSION
if [ $? != 0 ] 
   then
      echo "Please source .ascrc"
      exit 1
fi



#----------------------------------------
#set up the directories
#----------------------------------------
obsdir=`/home/anchors/bin/anchors_set_dirs.pl $obsid`
wavdir="$yaxx/Progs/WavDetect_RBA/";
echo $obsdir
echo $obsid2

#--------------------
#collect the data
#--------------------
cd $obsdir
#/home/anchors/bin/anchors_ret.csh $obsid
#gunzip -f *.gz

#evt2file=`ls acis*evt2.fits`
aspfile=`ls pcad*.fits`
evt2file="acis_evt2.fits"
#----------------------------------------
#reprocess with acis_process_events if 
# necessary, especially for cti correction
#----------------------------------------
#badprocess=0
#ver=`dmkeypar $evt2file ASCDSVER echo+`
#ver2=`echo $ver |sed 's/\.//g' `
#case $ver2 in
#     R*|r*) badprocess=1
#            esac           
#if [ $ver2 -lt 740 ]
#   then
#	badprocess=1
#fi
#if [ $badprocess -eq 1 ] 
#    then
#	echo "Need to reprocess level 1 file"
#	/home/anchors/bin/reprocess_level1.sh $obsid $obsdir
#        evt2file="acis_evt2.fits"
#fi
#exit
#----------------------------------------
#[SOURCE DETECTION]
#----------------------------------------
dmcopy infile=$evt2file'[energy=500:7500]' outfile=evt2_0.5-7.5_f.fits kernel=DEFAULT clobber+

ln -s $obsdir/evt2_0.5-7.5_f.fits $wavdir/$obsid2/0.5-7.5/evt2_0.5-7.5_f.fits
cd $wavdir
ls $obsdir/*asol* > asol1.lis
/home/anchors/bin/wave_run.csh $obsid2


#----------------------------------------
#[SOURCE REGIONS]
#----------------------------------------

cd $wavdir/$obsid2/0.5-7.5
cp evt2_0.5-7.5_fbin4_expmap.fits $obsdir
dmlist 'evt2_0.5-7.5_f_src.fits[cols shape,x,y,r,rotang]' data > src.reg
#-----------------------------
#convert the src.reg to a ds9 version and calc_theta_phi
#------------------------------
/home/anchors/bin/convert_src.pl src.reg
cd $yaxx/Progs
/home/anchors/bin/calc_theta_phi.pl $obsid


#------------------------------
#[IDL]
#------------------------------
#[output calc_theta_phi.out coluns:$src,$x,$y,$theta,$phi,$ra,$dec,$chip]
#[edit mk_psf_ellipse_reg.pro with background regions, lines 105-124]
echo "Please edit $yaxx/Progs/mk_psf_ellipse_reg.pro with the background regions"
echo "Please hit return when ready"
read moo;

idl <<EOF
.run mk_psf_ellipse_reg.pro
mk_psf_ellipse_reg

EOF

#------------------------------
#[RECENTROID]
#
#[output src_psf_ell.reg,bkg_psf_ell.reg - !skipping recentroiding for now!]
#------------------------------

#------------------------------
#[YAXX]
#------------------------------
cp src_psf_ell.reg src_psf_ell_$obsid.reg
cp bkg_psf_ell.reg bkg_psf_ell_$obsid.reg
cp calc_theta_phi.out calc_theta_phi_$obsid.out

/home/anchors/bin/distribute_reg.pl $obsid
cp sample.rdb $yaxx/$obsid2
cd $yaxx/$obsid2
cp ../yaxx.cfg .
cp ../yaxx.par .
mkdir param
unsetenv UPARM
../yaxx/yaxx

#------------------------------
#[POST_YAXX]
#------------------------------
#[ runs bblocks, quantiles, makes reports and web pages]
cd $yaxx/Progs
post_yaxx.pl ../04495/sample.rdb 4495 ../04495/Data/obs4495/evt2_0.5-7.5_fbin4_expmap.fits

echo "Processing complete"
