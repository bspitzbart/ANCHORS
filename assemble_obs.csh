/usr/bin/rm x642.xml
cat $yaxx/00642/642.xml x642.xml | grep -v "</OBS>" | grep -v "</root>" > x642.xml
cat $yaxx/00642/Data/obs642/src*/src*xml | grep -v "<\?" | grep -v "root>" | grep -v "created>" >> x642.xml
echo "</OBS></root>" >> x642.xml
xsltproc -o x642.html ../Data/anc_obs.xsl x642.xml
cp x642.html $anchors/00642/obs.html
