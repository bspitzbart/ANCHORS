#!/bin/bash 
# merge multiple asol files
#  otherwise coords a wrong in reprocessed evt2 when
#  first and second asol have different header keywords
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

tmpfile="merge_asol.tmp"
tmpoutfile="pcad_merge_asol1.fits"
cdir=`pwd`
cd $2
obsid=$1
if [ -f $tmpfile ] 
  then
    rm $tmpfile
fi
ls pcadf*.fits > $tmpfile
punlearn dmmerge
pset dmmerge infile=@$tmpfile
pset dmmerge outfile=$tmpoutfile
plist dmmerge >> $logfile
#dmmerge mode=h clobber+ verbose=2 >> $logfile
dmmerge mode=h clobber+ >> $logfile

rm pcadf*asol1.fits
rm $tmpfile
mv $tmpoutfile pcadf111111111N001_asol1.fits

