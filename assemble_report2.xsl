<?xml version="1.0"?><!--prod-imp.xsl-->
<!--XSLT 1.0 - http://www.CraneSoftwrights.com/training -->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="text"/>

  <xsl:param name="vsect">banner2</xsl:param>
  <xsl:param name="vobs">VOBS</xsl:param>
  <xsl:param name="vsrcid">VSRCID</xsl:param>

<!-- can not use param/var in match -->
<!-- here we'll assume we're using indiv. src.xml -->
<xsl:template match="//SOURCE[1]">
\documentclass[12pt]{article}
  \usepackage{color}
  \usepackage{graphics}
  \pagestyle{empty}
  \begin{document}

  <xsl:if test="$vsect='rep2banner'">
    <!-- /tmp/obs.xml must be created by assemble_report.pl -->
    <xsl:variable name="TOP" select="document('/tmp/obs.xml')"/>
    \begin{centerline}{\Large \bf 
                <xsl:value-of select="$TOP//OBS/NAME"/>
                \hspace{5ex} 
                ObsID= <xsl:value-of select="$vobs"/> 
                \hspace{2ex} 
                CCD= <xsl:value-of select="CCD_ID"/>
                \hspace{2ex} 
                SRC= <xsl:value-of select="@id"/> }
    \end{centerline}
  </xsl:if>

  <xsl:if test="$vsect='rep2sumbox'">
      \begin{tabular}{|l|l|}
      \hline
      Raw counts     &amp; <xsl:value-of select="CNTS"/>     \\ \hline
      Net counts     &amp; <xsl:value-of select="NET_CNTS"/> \\ \hline
      Exposure       &amp; <xsl:value-of select="EXP"/> s    \\ \hline
      RA             &amp; <xsl:value-of select="RA/@str"/>  \\ \hline
      Dec            &amp; <xsl:value-of select="DEC/@str"/> \\ \hline
      Off-axis       &amp; <xsl:value-of select="OFF_AX"/>'' \\ \hline
      \end{tabular}
  </xsl:if>

  <xsl:if test="$vsect='rep2spect'">
    <xsl:apply-templates select="SPECTRA"/>
  </xsl:if>

  <xsl:if test="$vsect='rep2quant'">
    \begin{tabular}{l|ccc}
    \multicolumn{4}{c}{Quantile Analysis} \\
    \hline
    &amp; 25\% &amp; 50\% &amp; 75\% \\
    \hline
    (keV) &amp; <xsl:value-of select="format-number(E25,'##.###')"/> &amp;
            <xsl:value-of select="format-number(E50,'##.###')"/> &amp;
            <xsl:value-of select="format-number(E75,'##.###')"/> \\
    error &amp; <xsl:value-of select="format-number(E25_err,'##.###')"/> &amp;
            <xsl:value-of select="format-number(E50_err,'##.###')"/> &amp;
            <xsl:value-of select="format-number(E75_err,'##.###')"/> \\
    (Q) &amp; <xsl:value-of select="format-number(Q25,'##.###')"/> &amp;
            <xsl:value-of select="format-number(Q50,'##.###')"/> &amp;
            <xsl:value-of select="format-number(Q75,'##.###')"/> \\
    error &amp; <xsl:value-of select="format-number(Q25_err,'##.###')"/> &amp;
            <xsl:value-of select="format-number(Q50_err,'##.###')"/> &amp;
            <xsl:value-of select="format-number(Q75_err,'##.###')"/> \\
    \hline
    \end{tabular}
  </xsl:if>

  <xsl:if test="$vsect='rep2hard'">
    \begin{tabular}{ccc}
    \multicolumn{3}{c}{Hardness Ratios} \\
    \hline
    &amp; H=0.3-0.9 keV &amp; M=0.9-1.5 &amp; 1.5-8.0 \\
    \hline
    HR1 &amp; <xsl:value-of select="format-number(HR1,'##.###')"/> &amp;
    (H-M)/(H+M) \\
    HR2 &amp; <xsl:value-of select="format-number(HR2,'##.###')"/> &amp;
    (M-S)/(M+S) \\
    HR3 &amp; <xsl:value-of select="format-number(HR3,'##.###')"/> &amp;
    (H-S)/(H+S) \\
    \hline
    \end{tabular}
  </xsl:if>

  <xsl:if test="$vsect='rep2lc'">
    <xsl:apply-templates select="BBLOCKS"/>
  </xsl:if>

  <xsl:if test="$vsect='rep2ir'">
    <xsl:variable name="IR" select="document('/tmp/2mass.xml')"/>
    \begin{tabular}{c|ccc}
    \multicolumn{4}{c}{2MASS} \\
    \hline
    &amp; RA &amp; Dec &amp; offset \\
    \hline
    &amp; 
    <xsl:value-of select="$IR//SOURCE/tmass_ra"/> &amp;
    <xsl:value-of select="$IR//SOURCE/tmass_dec"/> &amp;
    <xsl:value-of select="$IR//SOURCE/offset"/> \\
    \hline
    band&amp; mag &amp; err &amp; flags \\
    \hline
    J &amp; 
    <xsl:value-of select="$IR//SOURCE/j_mag"/> &amp; 
    <xsl:value-of select="$IR//SOURCE/j_mag_e"/> &amp; \\
    H &amp; 
    <xsl:value-of select="$IR//SOURCE/h_mag"/> &amp; 
    <xsl:value-of select="$IR//SOURCE/h_mag_e"/> &amp; \\
    K &amp; 
    <xsl:value-of select="$IR//SOURCE/k_mag"/> &amp; 
    <xsl:value-of select="$IR//SOURCE/k_mag_e"/> &amp; \\
    \hline
    \end{tabular}
  </xsl:if>

\end{document}
</xsl:template>

<xsl:template match="SPECTRA">
\centering{
\begin{tabular}{lccccccc}
\hline
 &amp; wabs &amp; R-S  &amp; R-S2 
  &amp; abs.flux &amp; unabs.flux1 &amp; unabs.flux2 
  &amp; red. $\chi^{2}$\\ 
 &amp; nH &amp; kT &amp; kT &amp; 
 ergs/cm$^2$/s &amp;
 ergs/cm$^2$/s &amp;
 ergs/cm$^2$/s &amp;
 (DOF)\\ 
 &amp;  $10^{22}$ &amp;  &amp; &amp; &amp; &amp; &amp; \\ 
  <!--<xsl:variable name="amodel" select="SPECTRA/MODEL[@name='bbrs']"/>-->
  <xsl:apply-templates select="MODEL[@name='cstat']"/>
  <xsl:apply-templates select="MODEL[@name='c_rs']"/>
  <xsl:apply-templates select="MODEL[@name='c_rs2']"/>
  <xsl:apply-templates select="MODEL[@name='c_rs2a']"/>
\hline
\end{tabular}
</xsl:template>

<xsl:template match="MODEL">
\hline
    <xsl:value-of select="@name"/> &amp;
    <xsl:value-of select="NH"/>
    $_{<xsl:value-of select="NH_ERR"/>}$ &amp;
    <xsl:value-of select="KT"/>
    $_{<xsl:value-of select="KT_ERR"/>}$ &amp;
    <xsl:value-of select="KT2"/>
    $_{<xsl:value-of select="KT2_ERR"/>}$ &amp;
    <xsl:value-of select="FLUX"/> &amp;
    <xsl:value-of select="KT_FLUX"/> &amp;
    <xsl:value-of select="KT2_FLUX"/> &amp;
    <xsl:value-of select="CHI"/>
    (<xsl:value-of select="DOF"/>) \\
</xsl:template>

<xsl:template match="BBLOCKS">
\begin{tabular}{cccc}
\multicolumn{4}{c}{Bayesian Block Analysis} \\
\hline
 block &amp; rate &amp; error  &amp; time\\
\hline
  <xsl:apply-templates select="BBLOCKS_SIG/BBLOCKS_N"/>
\end{tabular}
</xsl:template>

<xsl:template match="BBLOCKS_N">
    <xsl:value-of select="@n"/> &amp;
    <xsl:value-of select="BBLOCKS_RATE"/> &amp;
    <xsl:value-of select="BBLOCKS_ERR"/> &amp;
    <xsl:value-of select="BBLOCKS_DT"/> \\
\hline
</xsl:template>

</xsl:stylesheet>
