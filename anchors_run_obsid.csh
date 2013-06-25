#! /usr/bin/tcsh -f
###############################################################################
#ANCHORS pipeline by obsid
#
#
#Nancy Adams-Wolk 1/13/06
#
###############################################################################
if ($# < 1) then
	echo "usage: $0 <obsid> "
	exit
endif

#----------------------------------------
#want obsid in both 4 and 5 digit format
#----------------------------------------
set obsid = $1
set foo=`echo $obsid | wc -c`
if ($foo != 6) then
    set obsid2 = "0$obsid"
else
    set obsid2="$obsid"
endif

#------------------------
#confirm ascds is set
#------------------------
env | grep ASCDS_VERSION
if ($? != 0 ) then
 echo "Please source .ascrc"
 exit 1
endif


#----------------------------------------
#set up the directories
#----------------------------------------
set obsdir=`/home/anchors/bin/anchors_set_dirs.pl $obsid`
set wavdir="$yaxx/Progs/WavDetect_RBA/";
echo $obsdir


#--------------------
#collect the data
#--------------------
cd $obsdir
/home/anchors/bin/anchors_ret.csh $obsid
gunzip *.gz

set evt2file=`ls acis*evt2.fits`
set aspfile=`ls pcad*.fits`

#----------------------------------------
#[reprocess with acis_process_events if 
# necessary, especially for cti correction]
#----------------------------------------
set check_cti=`dmlist $evt2file header | grep apply_cti`
if (x$check_cti == 'x') then
   echo "Need to cti correct this file"
   exit
   #enter code here to cti correct...
endif

#----------------------------------------
#[SOURCE DETECTION]
#----------------------------------------
dmcopy infile=$evt2file'[energy=500:7500]' outfile=evt2_0.5-7.5_f.fits kernel=DEFAULT clobber+

ln -s $obsdir/evt2_0.5-7.5_f.fits $wavedir/$obsid2/0.5-7.5/evt2_0.5-7.5_f.fits
cd $wavdir
ls $obsdir/*asol* >! asol1.lis
/home/anchors/bin/wave_run.csh $obsid2


#----------------------------------------
#[SOURCE REGIONS]
#----------------------------------------
cd $wavdir/$obsid2/0.5-7.5
cp evt2_0.5-7.5_fbin4_expmap.fits $obsdir
dmlist 'evt2_0.5-7.5_f_src.fits[cols shape,x,y,r,rotang]' data > src.reg
#[edit src.reg to make regions file.  DS9 should read the fits file, but I can't
#  get it to.]
dmlist 'evt2_0.5-7.5_f_src.fits[cols x,y]' data | awk '{print$3" "$4}' | sed -e 's/,//' | sed -e 's/)//' | tail +8 > ! $yaxx/Progs/calc_theta_phi.lst
cd $yaxx/Progs

/home/anchors/bin/calc_theta_phi.pl $obsid

echo "Need to continue with IDL"

#[output calc_theta_phi.out coluns:$src,$x,$y,$theta,$phi,$ra,$dec,$chip]
#[edit mk_psf_ellipse_reg.pro with background regions, lines 105-124]
#anchors on rhodes> idl
#IDL> mk_psf_ellipse_reg
#[output src_psf_ell.reg,bkg_psf_ell.reg - !skipping recentroiding for now!]

#[YAXX]
#anchors on rhodes> cp src_psf_ell.reg src_psf_ell_4495.reg
#anchors on rhodes> cp bkg_psf_ell.reg bkg_psf_ell_4495.reg
#anchors on rhodes> cp calc_theta_phi.out calc_theta_phi_4495.out
#anchors on rhodes> vi distribute_reg.pl
[edit obsid]
#anchors on rhodes> distribute_reg.pl
#anchors on rhodes> cp sample.rdb $yaxx/04495
#anchors on rhodes> cd $yaxx/04495

#anchors on rhodes> cp ../yaxx.cfg .
#anchors on rhodes> cp ../yaxx.par .
#anchors on rhodes> mkdir param
#anchors on rhodes> unsetenv UPARM
#anchors on rhodes> ../yaxx/yaxx

#[POST_YAXX]
#[ runs bblocks, quantiles, makes reports and web pages]
#anchors on rhodes> cd $yaxx/Progs
#anchors on rhodes> post_yaxx.pl ../04495/sample.rdb 4495
#../04495/Data/obs4495/evt2_0.5-7.5_fbin4_expmap.fits
