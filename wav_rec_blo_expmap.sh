#!/bin/sh

########################################################################
###
### Running wavdetect in the "recursive blocking" scheme,
### i.e. center in full resolution, then 2x center image blocked by 2,
### etc., sources only taken from annuli totally enclosed in the
### analyzed data set, excluding sources detected earlier
### in higher resolution.
###
### Usage:
###    wav_rec_blo.sh input_evt_list list_of_asol_files output_source_list
###
### Work images are hardwired to 1800kx1800k, except for the last one, which
### (to save computation time) is set to actual extent of the dataset.
### Off-axis angle annuli hardwired to 0-800, 800-1600, etc.
### Can be changed, but I see no real reason why...
###
### To change wavelet scales used, locate the
###    pset wavdetect scales=...
### line below and edit accordingly.
###
### Some sanity/error checks are done before and during the run, but not
### every imaginable one.
###
### Author:
###    Adam Dobrzycki, adam@head-cfa.harvard.edu
###    May 2002
### edited to use the anchors paths
########################################################################

### initial tests

COMMAND=`basename $0`
if [ \( $# -ne 3 \) ] ; then
    echo "Usage: $COMMAND event_list list_of_asol1_files source_list"
    exit 1
fi

if [ "${ASCDS_LIB}" = "" ] ; then
    echo "ASCDS/CIAO not set up, aborting"
    exit 1
fi

if [ ! -f $1 ] ; then
    echo "File $1 does not exist, aborting"
    exit 1
fi
fname=$1

if [ ! -f $2 ] ; then
    echo "File $2 does not exist, aborting"
    exit 1
fi
asollist=$2

if [ -f $3 ] ; then
    echo "File $3 exists, exiting"
    exit 1
fi
outfname=$3
/bin/rm -f ${outfname} 2> /dev/null

########################################################################

### start

echo
kiedy=`date`
echo "=== $kiedy $COMMAND - start"

### setup wavdetect

punlearn wavdetect
punlearn wtransform
punlearn wrecon
pset wavdetect scales="2.0 4.0 8.0 16.0 32.0"
pset wavdetect clobber=yes

currentdir=`pwd`

########################################################################

### read allowed x,y range from the event list

zmin=`dmlist ${fname}"[events]" cols | egrep -i "sky\(x,y\)" | gawk '{print $5}' | cut -f1 -d':'`
zmax=`dmlist ${fname}"[events]" cols | egrep -i "sky\(x,y\)" | gawk '{print $6}'`
zc=`echo $zmin $zmax | gawk '{print int(0.5*($1+$2))}'`

### read actual x,y range from the event list

dmstat ${fname}"[cols x,y]" | egrep "min|max" | gawk '{print int($3),int($4)}' > /tmp/${COMMAND}_xy_$$
if [ $? -ne 0 ] ; then
    echo "=== $COMMAND - non-zero exit status from dmstat, aborting"
    exit 1
fi

xx0=`head -1 /tmp/${COMMAND}_xy_$$ | gawk '{print int($1)}'`
yy0=`head -1 /tmp/${COMMAND}_xy_$$ | gawk '{print int($2)}'`
rmin=${xx0}
if [ ${yy0} -lt ${xx0} ] ; then
    rmin=${yy0}
fi
xx1=`tail -1 /tmp/${COMMAND}_xy_$$ | gawk '{print int($1)+1}'`
yy1=`tail -1 /tmp/${COMMAND}_xy_$$ | gawk '{print int($2)+1}'`
rmax=${xx1}
if [ ${yy1} -gt ${xx1} ] ; then
    rmax=${yy1}
fi


/bin/rm -f /tmp/${COMMAND}_xy_$$ 2> /dev/null

range0=`echo $zc $rmin | gawk '{print $1-$2}'`
range1=`echo $zc $rmax | gawk '{print $2-$1}'`
ranmax=${range0}
if [ ${range0} -lt ${range1} ] ; then
    ranmax=${range1}
fi


### setups

/bin/rm -f temp_src_$$.stk 2> /dev/null
touch temp_src_$$.stk

step=900
annstep=800
go_on="TRUE"
binfactor=1
ann0=0


### get "chip" for merge_all

instrume=`dmlist $fname header verbose=0 | egrep INSTRUME | gawk '{print $3}'`
if [ "$instrume" = "ACIS" ] ; then
    chps=`dmlist $fname header verbose=0 | egrep DETNAM | gawk '{print $3}' | cut -f2 -d"-"`
    ile=`echo $chps | wc -c | gawk '{print $1-1}'`
    chip=""
    i=1
    while [ $i -le $ile ] ; do
	chip=${chip}`echo $chps | cut -c${i}`
	if [ $i -lt $ile ] ; then
	    chip=${chip}","
	fi
	i=`echo $i | gawk '{print $1+1}'`
    done
else
    chip=`dmlist $fname header verbose=0 | egrep DETNAM | gawk '{print $3}'`
fi


punlearn merge_all

/bin/rm -f imap_*fits emap_*fits merged_asp_*fits 2> /dev/null


### get asol files


while [ "${go_on}" = "TRUE" ] ; do

    echo
    kiedy=`date`
    echo "=== $kiedy $COMMAND - working on bin factor $binfactor"

### set range for binned image

    z0=`echo $zc $binfactor $step | gawk '{printf("%.1f\n",$1-$2*$3+0.5)}'`
    z1=`echo $zc $binfactor $step | gawk '{printf("%.1f\n",$1+$2*$3+0.5)}'`

### check if both z0 and z1 are outside of event range
### if yes, set things up so that the last image is only as large as needed
### and set exit condition for the loop

    tescikz0=`echo ${z0} ${rmin} | gawk '{print int($1-$2)}'`
    tescikz1=`echo ${z1} ${rmax} | gawk '{print int($2-$1)}'`

    if [ \( ${tescikz0} -lt 0 \) -a \( ${tescikz1} -lt 0 \) ] ; then
	go_on="FALSE"
	ranfinal=`echo $ranmax $binfactor | gawk '{print (int(2*$1/$2)+1)*$2}'`
	z0=`echo $zc $ranfinal | gawk '{printf("%.1f\n",$1-$2/2.0+0.5)}'`
	z1=`echo $zc $ranfinal | gawk '{printf("%.1f\n",$1+$2/2.0+0.5)}'`
    fi


### produce binned image

    oldtext="\.fits"
    newtext="bin${binfactor}\.fits"
    binfile=`echo ${fname} | sed -e "s/$oldtext/$newtext/"`
    dmcopy ${fname}"[bin x=${z0}:${z1}:${binfactor},y=${z0}:${z1}:${binfactor}]" ${binfile} clobber=yes
    if [ $? -ne 0 ] ; then
	echo "=== $COMMAND - non-zero exit status of dmcopy, aborting"
	exit 1
    fi

### produce exposure map

    npix=`echo ${z0} ${z1} ${binfactor} | gawk '{print int(($2-$1)/$3+0.5)}'`
    xygrid="${z0}:$z1:#${npix},${z0}:$z1:#${npix}"
    newtext="bin${binfactor}_expmap\.fits"
    expmap=`echo ${fname} | sed -e "s/$oldtext/$newtext/"`
    newtext="bin${binfactor}_expcorr\.fits"
    expcorr=`echo ${fname} | sed -e "s/$oldtext/$newtext/"`

    res_xy=`echo $binfactor | gawk '{print 0.5*$1}'`
#    res_xy='4.0'
    res_xy='1.968'
    pset asphist res_xy=${res_xy}

    echo ${res_xy}
    
    plist asphist

    kiedy=`date`
    echo "=== $kiedy $COMMAND - running merge_all for bin factor $binfactor"
    
    expm_std="${currentdir}/emap${binfactor}_stdfile"
    expm_time="${currentdir}/emap${binfactor}_time"
 
    pset merge_all evtfile="${fname}" asol="@${asollist}" dtffile="" \
    chip="$chip" refcoord="" xygrid="${xygrid}" energy=1.49 merged="" \
    expmap="${expmap}" expcorr="${expcorr}" intdir="${currentdir}" \
    clobber="yes" mode="hl"

  
    (time perl /home/anchors/bin/merge_all  > ${expm_std} ) > ${expm_time}

    if [ $? -ne 0 ] ; then
	echo "=== $COMMAND: non-zero exit status from merge_all, aborting"
	exit 1
    fi

    /bin/rm -f imap_*fits emap_*fits merged_asp_*fits 2> /dev/null



### setup wavdetect

    infile=$binfile
    tempoutfile=`echo $infile | sed s/"\.fits"/"_tsrc\.fits"/`
    scellfile=`echo $infile | sed s/"\.fits"/"_scell\.fits"/`
    imagefile=`echo $infile | sed s/"\.fits"/"_img\.fits"/`
    defnbkgfile=`echo $infile | sed s/"\.fits"/"_bkg\.fits"/`

### run wavdetect

    echo
    kiedy=`date`
    echo "=== $kiedy $COMMAND - running wavdetect for bin factor $binfactor"
    
    wav_std="${currentdir}/wav${binfactor}_stdfile"
    wav_time="${currentdir}/wav${binfactor}_time"

    pset wavdetect infile=${infile} outfile=${tempoutfile} \
	 scellfile=${scellfile} imagefile=${imagefile} \
         defnbkgfile=${defnbkgfile} expfile=${expmap} verbose=2  mode="hl"
    
   (time wavdetect > ${wav_std} ) > ${wav_time}

    if [ $? -ne 0 ] ; then
	echo "=== $COMMAND: non-zero exit status from wavdetect, aborting"
	exit 1
    fi

### select sources from appropriate annulus

    outfile=`echo $infile | sed s/"\.fits"/"_src\.fits"/`
    ann1=`echo $binfactor $annstep | gawk '{print $1*$2}'`

    echo
    kiedy=`date`
    echo "=== $kiedy $COMMAND - selecting appropriate sources"
    dmcopy ${tempoutfile}"[(x,y)=annulus(${zc},${zc},${ann0},${ann1})]" $outfile
    if [ $? -ne 0 ] ; then
	echo "=== $COMMAND - non-zero exit status from dmcopy, aborting"
	exit 1
    fi
    echo $outfile >> temp_src_$$.stk

### increase blocking factor, set low annulus radius to the old high radius

    binfactor=`echo $binfactor | gawk '{print $1*2}'`
    ann0=${ann1}

done

### merge partial source lists

echo
kiedy=`date`
echo "=== $kiedy $COMMAND - done with wavdetect runs, running dmmerge"

punlearn dmmerge
lookuptab=`pget dmmerge lookupTab`
dmmerge infile="@temp_src_$$.stk" columnList="" outfile="${outfname}" outBlock="" lookupTab="${lookuptab}" clobber=yes
if [ $? -ne 0 ] ; then
    echo "=== $COMMAND - problem with dmmerge, aborting"
    exit 1
fi

### cleanup and exit

### /bin/rm -f *bin* 2> /dev/null
### /bin/rm -f temp_src_$$.stk 2> /dev/null

echo
kiedy=`date`
echo "=== $kiedy $COMMAND - stop, normal exit"
exit 0
