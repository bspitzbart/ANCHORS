#!/bin/bash 
# Rerun the level 1 file to create a new level 2 file
#------------------------------------------------------------

if [ $# -lt 2 ]
    then
        echo "useage: $0 <obsid> <directory>"
        exit 1
 fi

if [ $# -eq 3 ]
    then
         logfile=$3
    else
         logfile="$2/reprocess_level1.log"
fi

cdir=`pwd`
cd $2
obsid=$1
###/home/anchors/bin/anchors_ret_level1.csh $obsid
gunzip -f *.gz
evt1file=`ls acisf*N*evt1.fits`
mv $evt1file "acis_evt1.fits"
mv acisf*N*flt1.fits acis_flt1.fits
#----------------------------------------
# Reset Status Bits to remove acis_detect_afterglow
#----------------------------------------
#---check the version
badprocess=0
ver=`dmkeypar acis_evt1.fits ASCDSVER echo+`
ver2=`echo $ver |sed 's/\.//g' `
echo $ver2
case $ver2 in
     R*|r*) badprocess=1
            esac           

echo $badprocess
if [ $badprocess -ne 1 ]
   then
   if [ $ver2 -lt 740 ]
      then
	badprocess=1
   fi
fi

if [ $badprocess -eq 1 ]
   then
	punlearn dmtcalc
	pset dmtcalc infile=acis_evt1.fits
	pset dmtcalc outfile=acis_reset_evt1.fits
	pset dmtcalc expression="status=status,status=X15F,status=X14F,status=X13F,status=X12F"
	plist dmtcalc >> $logfile
	dmtcalc mode=h clobber+ verbose=2 >> $logfile
	
   else
	mv acis_evt1.fits acis_reset_evt1.fits
fi



#-------------------------------------------------------
#******2. Identify ACIS Hot Pixels and Cosmic Ray Afterglows
#-------------------------------------------------------
ls acis*bias0.fits >bias_files.lis

pbk=`ls acis*pbk0.fits`
bpix1=`ls acis*bpix1.fits`
msk1=`ls acis*msk1.fits`
asol1=`ls pcad*asol1.fits`

#--Create a New Bad Pixel File:
 punlearn acis_run_hotpix
 pset acis_run_hotpix infile=acis_reset_evt1.fits
 pset acis_run_hotpix outfile=acis_new_bpix1.fits
 pset acis_run_hotpix badpixfile=$bpix1
 pset acis_run_hotpix biasfile=@bias_files.lis 
 pset acis_run_hotpix maskfile=$msk1
 pset acis_run_hotpix pbkfile=$pbk
 plist acis_run_hotpix >> $logfile
 acis_run_hotpix mode=h clobber+ verbose=2 >> $logfile


#---Set up for new acis_process_events run

readmode=`dmkeypar acis_reset_evt1.fits READMODE echo+`
datamode=`dmkeypar acis_reset_evt1.fits DATAMODE echo+`
fptemp=`dmkeypar acis_reset_evt1.fits FP_TEMP echo+`
#--------------------------------------------------------
#TIMED:  (V)FAINT = timed exposure (very) faint -->stdlev1
#TIMED:  GRADED   = timed exposure graded       -->grdlev1
#-------------------------------------------------------

if [ $readmode = "TIMED" ]
   then
        case $datamode in
	
                GRADED) cols="grdlev1"
                    ;;
                *) cols="stdlev1"
                   ;;
	esac
fi
#don't run these if bad temp? DO we care?
#if [ $fptemp -lt 157 ] && [ $fptemp -gt 151]
#   then
#     pset acis_process_events apply_cti=no
#     pset acis_process_events apply_tgain=no
#fi


#--Run acis_process_events:
 punlearn acis_process_events
 pset acis_process_events infile=acis_reset_evt1.fits
 pset acis_process_events outfile=acis_new_evt1.fits
 pset acis_process_events badpixfile=acis_new_bpix1.fits
 pset acis_process_events acaofffile=$asol1
 pset acis_process_events eventdef=")$cols"
 if [ $datamode = "VFAINT" ]
    then
	 pset acis_process_events check_vf_pha=yes
 fi
 plist acis_process_events >> $logfile
 acis_process_events mode=h clobber+ verbose=2 >> $logfile

#-------------------------------------------------------
# Make the level 2 file
#-------------------------------------------------------

punlearn dmcopy
dmcopy infile="acis_new_evt1.fits[EVENTS][grade=0,2,3,4,6,status=0]" outfile=acis_flt_evt1.fits mode=h clobber+ verbose=2 >> $logfile

punlearn dmcopy
dmcopy "acis_flt_evt1.fits[EVENTS][@acis_flt1.fits][cols -phas]" acis_tmp_evt2.fits mode=h clobber+ verbose=2>> $logfile

##--Destreaking the evt2 file:
 punlearn destreak
 pset destreak infile=acis_tmp_evt2.fits
 pset destreak outfile=acis_evt2.fits
 destreak mode=h clobber+ verbose=2 >> $logfile

#----------------------------------------
#cleanup
#----------------------------------------
for file in `ls acisf*.fits`
    do
	if [ -f $file ]
           then
	   rm $file
	fi
    done

rm  bias_files.lis

#------------------------------
#last cleanup
#------------------------------
if [ -f acis_evt2.fits ]
   then
	echo ""
   else
	mv acis_tmp_evt2.fits acis_evt2.fits
       
fi


