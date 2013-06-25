#! /usr/bin/sh 
###############################################################################
#ANCHORS pipeline by obsid
#  this version starts after wavdetection
#   commented out lines marked with #nowav
#   11. Jul 2006 BDS
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
logfile="$obsdir/anchors$obsid.log"
echo "ANCHORS***ANCHORS***ANCHORS Starting Processing" >>$logfile
date >> $logfile
#--------------------
#collect the data
#--------------------
cd $obsdir
#/home/anchors/bin/anchors_ret.csh $obsid
gunzip -f *.gz

#evt2file=`ls acisf${obsid2}*evt2.fits`
#  use evt2_efilt, produced before detect, acisf*evt2 might already be gone
evt2file=`ls evt2_efilt.fits`
aspfile=`ls pcad*.fits`
nsol=`ls pcadf*.fits | wc -l`
echo "$nsol"
if [ $nsol -gt 1 ]
  then
#nowav    echo "Need to merge asol files"
    echo "asol files should already be merged"
#nowav    /home/anchors/bin/merge_asol.sh $obsid $obsdir $logfile
fi

#----------------------------------------
#reprocess with acis_process_events if 
# necessary, especially for cti correction
#----------------------------------------
badprocess=0
ver=`dmkeypar $evt2file ASCDSVER echo+`
obs_roll=`dmkeypar $evt2file ROLL_NOM echo+`
ver2=`echo $ver |sed 's/\.//g' `
case $ver2 in
     R*|r*) badprocess=1
            esac           
if [ $badprocess -ne 1 ]
   then
   if [ $ver2 -lt 740 ]
      then
	 badprocess=1
   fi
fi
if [ $badprocess -eq 1 ] 
    then
#nowav	echo "Need to reprocess level 1 file"
#nowav	echo "ANCHORS: Reprocessing level 1 file with reprocess level1" >> $logfile 
#nowav	/home/anchors/bin/reprocess_level1.sh $obsid $obsdir $logfile
        evt2file="acis_evt2.fits"
fi
#----------------------------------------
#[SOURCE DETECTION]
#----------------------------------------
#nowav echo "ANCHORS:Starting source detection" >> $logfile
#nowav dmcopy infile=$evt2file'[energy=300:8000]' outfile=evt2_efilt.fits kernel=DEFAULT clobber+ verbose=2 1>> $logfile 2>&1

#nowav ln -s $obsdir/evt2_efilt.fits $wavdir/$obsid2/0.3-8.0/evt2_efilt.fits
cd $wavdir/$obsid2/0.3-8.0/
#nowav ls $obsdir/*asol* > asol1.lis
#nowav /home/anchors/bin/wave_run.csh $obsid2 $logfile
 

#----------------------------------------
#[SOURCE REGIONS]
#----------------------------------------
echo "ANCHORS:Source Region Processing" >> $logfile
cp evt2_efiltbin4_expmap.fits $obsdir
dmlist 'evt2_efilt_src.fits[cols shape,x,y,r,rotang][src_significance >= 3.5]' data outfile=src.reg  1>> $logfile 2>&1

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
#echo "ANCHORS:Editing $yaxx/Progs/mk_psf_ellipse_reg.pro with the background regions" >> $logfile
#echo "Please edit $yaxx/Progs/mk_psf_ellipse_reg.pro with the background regions"
#echo "Please hit return when ready"
#read moo;

idl <<EOF
.run $yaxx/Progs/mk_psf_ellipse_exc.pro
mk_psf_ellipse_exc, $obsid, $obs_roll

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
echo "ANCHORS: Preparing and running YAXX" >> $logfile
echo "ANCHORS: running distribute_reg.pl" >> $logfile
/home/anchors/bin/distribute_reg.pl $obsid
cp sample.rdb $yaxx/$obsid2
cd $yaxx/$obsid2
cp ../yaxx.cfg .
cp ../yaxx.par .
mkdir param
#----------------------------------------
#restet for CIAO as we need psextract
#----------------------------------------
echo "ANCHORS: Resetting CIAO " >> $logfile
ASCDS_OVERRIDE=1
. /soft/ciao/bin/ciao.bash 
#Record the CIAO versions
if [ -f $ASCDS_INSTALL/VERSION ] ; then
    echo " CIAO version     : " `cat $ASCDS_INSTALL/VERSION` >> $logfile
fi
if [ -f $ASCDS_INSTALL/VERSION.prop_tk ] ; then
    echo " Proposal Toolkit version : " `cat $ASCDS_INSTALL/VERSION.prop_tk` >> $logfile
fi
echo    " bin dir          : " $ASCDS_BIN >>$logfile
#end recording the new ciao 


unset UPARM
../yaxx/yaxx 1>> $logfile 2>&1

#------------------------------
#[POST_YAXX]
#------------------------------
#[ runs bblocks, quantiles, makes reports and web pages]
echo "ANCHORS: Running Post YAXX processing" >> $logfile
cd $yaxx/Progs
/home/anchors/bin/post_yaxx.pl ../${obsid2}/sample.rdb ${obsid} evt2_efiltbin4_expmap.fits  1>> $logfile 2>&1

echo "ANCHORS:Processing complete" >> $logfile
date >> $logfile
echo "Processing complete"
