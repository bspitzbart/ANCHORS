<?xml version="1.0"?><!--prod-imp.xsl-->
<!--XSLT 1.0 - http://www.CraneSoftwrights.com/training -->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="text"/>

  <!--<xsl:param name="vobs">4503</xsl:param>-->
  <!--<xsl:param name="vsrcid">1</xsl:param>-->

<xsl:template match="/SOURCE[@id='1']">
<!--
  <xsl:variable name="src" select="//SOURCE[@id='1']"/>
\documentclass[12pt]{article}
  \usepackage{color}
  \usepackage{graphics}
  \textwidth 7.in
  \textheight 10in
  \topmargin -.75in
  \oddsidemargin 0.0in
  \pagestyle{empty}
  \parskip 0em
  \parindent 0em
  \begin{document}\centerline{\Large \bf RCW 108  \hspace{5ex} 
              ObsID=4503 \hspace{2ex} CCD=3 \hspace{2ex} SRC=$src }
  \vspace*{.1in}\parbox[t]{3in}{
      \large
      \begin{tabular}{|l|l|}
      \hline
-->
Grape
      <xsl:text>Counts         &amp; </xsl:text> <xsl:value-of select="CNTS"/>
 \\         \hline
\end{document}
</xsl:template>
</xsl:stylesheet>
