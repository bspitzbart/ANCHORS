#!/bin/csh
#
if ($#argv < 1) then
	echo "usage: $0 <obsid> "
	exit
endif
set obsid = $1

set logfile='/data/ANCHORS/YAXX/WavDetect_RBA/$obsid/0.3-8.0/wave_run_$obsid.log'
if ($#argv == 2) then
     set logfile=$argv[2]
endif

echo "ANCHORS:Resetting CIAO and Parameters" >> $logfile
source /soft/ciao3.4/bin/ciao.csh -o
source /data/ANCHORS/YAXX/bin_linux/reset_param

#
#
pwd
set infile="/data/ANCHORS/YAXX/WavDetect_RBA/$obsid/0.3-8.0/evt2_efilt.fits"
set outfile=`echo $infile | sed s/"\.fits"/"_src\.fits"/`
set aspfile="/data/ANCHORS/YAXX/WavDetect_RBA/$obsid/0.3-8.0/asol1.lis"
#
echo $infile
echo $outfile
echo $aspfile
#
# Run wav_rec_blo_expmap.sh
#

/home/anchors/bin/wav_rec_blo_expmap.sh $infile $aspfile $outfile > wave_tot_stdfile 

echo "ANCHORS: wav_rec_blo_expmap.sh output" >> $logfile
cat /data/ANCHORS/YAXX/WavDetect_RBA/$obsid/0.3-8.0/wave_tot_std >> $logfile
cat /data/ANCHORS/YAXX/WavDetect_RBA/$obsid/0.3-8.0/*_time >> $logfile

#   
