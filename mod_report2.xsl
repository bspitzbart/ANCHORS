<?xml version="1.0"?><!--prod-imp.xsl-->
<!--XSLT 1.0 - http://www.CraneSoftwrights.com/training -->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="text"/>

  <xsl:param name="vobs">VOBS</xsl:param>
  <xsl:param name="vsrcid">VSRCID</xsl:param>

<!-- can not use param/var in match -->
<!-- here we'll assume we're using indiv. src.xml -->
<xsl:template match="//SOURCE[1]">
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
  \begin{document}\centerline{\Large \bf OBJ\_NAME
              \hspace{5ex} 
              ObsID= <xsl:value-of select="$vobs"/> 
              \hspace{2ex} CCD=N \hspace{2ex} 
              SRC= <xsl:value-of select="@id"/> }

  \vspace*{.1in}\parbox[t]{3in}{
      \large
      \begin{tabular}{|l|l|}
      \hline
      Counts         &amp; <xsl:value-of select="CNTS"/> \\         \hline
      Exposure       &amp; 88812 \\       \hline
      RA             &amp; <xsl:value-of select="RA/@str"/> \\             \hline
      Dec            &amp; <xsl:value-of select="DEC/@str"/> \\            \hline
      Off-axis       &amp; <xsl:value-of select="OFF_AX"/>'' \\            \hline
      \end{tabular}
  } 
  \hfill
  %
  % DS9 image
  %
  \raisebox{-.5\height}{
      \fbox{
         \resizebox{2.5in}{!}{
            \includegraphics{image.ps}
         }
      }
  }
  \vspace*{.2in}

<xsl:apply-templates select="SPECTRA"/>
\vspace*{.2in}

\resizebox{2.25in}{!}{\includegraphics{bbrs.ps}} 
\resizebox{2.25in}{!}{\includegraphics{bbrs2.ps}} 
\resizebox{2.25in}{!}{\includegraphics{bbrs2a.ps}} 

\begin{table}[hb]
\begin{minipage}[b]{0.30\columnwidth}%
    \centering

\begin{tabular}{l|ccc}
\multicolumn{4}{c}{Quantile Analysis} \\
\hline
&amp; 25\% &amp; 50\% &amp; 75\% \\
\hline
(keV) &amp; <xsl:value-of select="format-number(Q25,'##.###')"/> &amp;
        <xsl:value-of select="format-number(Q50,'##.###')"/> &amp;
        <xsl:value-of select="format-number(Q75,'##.###')"/> \\
error &amp; <xsl:value-of select="format-number(Q25_err,'##.###')"/> &amp;
        <xsl:value-of select="format-number(Q50_err,'##.###')"/> &amp;
        <xsl:value-of select="format-number(Q75_err,'##.###')"/> \\
\hline
\end{tabular}
\ \\
  \vspace*{.2in}

<xsl:apply-templates select="BBLOCKS"/>
%\ \\
\end{minipage}%
%\hfill%
\begin{minipage}[b]{0.30\columnwidth}%

%\ \\
\resizebox{2.10in}{!}{\includegraphics{bblocks_plot.ps}}
\end{minipage}%

\begin{minipage}[b]{0.30\columnwidth}%
\begin{tabular}{c|ccc}
\multicolumn{4}{c}{2MASS} \\
\hline
band&amp; mag &amp; err &amp; flags \\
\hline
J &amp; &amp; &amp; \\
H &amp; &amp; &amp; \\
K &amp; &amp; &amp; \\
\hline
\end{tabular}
\end{minipage}%

\end{table}

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
  <xsl:apply-templates select="MODEL[@name='bbrs']"/>
  <xsl:apply-templates select="MODEL[@name='bbrs2']"/>
  <xsl:apply-templates select="MODEL[@name='bbrs2a']"/>
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
