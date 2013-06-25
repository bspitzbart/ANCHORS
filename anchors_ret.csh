#! /usr/bin/tcsh -f
###############################################################################
#ANCHORS retrieve
#
#will retrieve data with arc4gl
#
###############################################################################
if ($# < 1) then
	echo "usage: $0 <obsid>"
	exit
endif


set obsid = $1


cat <<EOF >> getdata2

operation=retrieve
dataset=flight
detector=acis
level=2
filetype=evt2
obsid=$obsid
go

operation=retrieve
dataset=flight
detector=pcad
subdetector=aca
obsid=$obsid
level=1
filetype=aspsol
go

EOF


echo "I'm getting your data"


arc4gl -igetdata2
if ( $? == 0 ) then
  echo "Data collected"
else
  echo "arc4gl error"
endif

rm getdata2




