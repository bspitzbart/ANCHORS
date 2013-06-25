<?xml version="1.0"?><!--prod-imp.xsl-->
<!--XSLT 1.0 - http://www.CraneSoftwrights.com/training -->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="html"/>
<xsl:template match="//OBS">
<html xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
      xsl:version="1.0">

  <!-- 
       !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
       do not know how to use variable and xsl:if inside
       xsl:apply-template to set sortcolumn.
       So any changes made here also need to be made
       to anc_obs_cnts.pl, anc_obs_bb.pl, anc_obs_id.pl
       !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  -->

  <xsl:param name="sortcol">cnts</xsl:param>
  <!--<xsl:param name="sortdir">SORTDIR</xsl:param>-->
  <xsl:param name="vobs">VOBS</xsl:param>

  <head><title><xsl:value-of select="NAME"/></title>
  <link rel="stylesheet" href="../anchors.css" type="text/css"/>
  </head>
  <body>
<center>
 
<!-- OBJ Details -->
<table border="2" bgcolor="#ffffff">
<tr><td>
<h1><xsl:value-of select="NAME"/></h1><br/>
<ul>
<li>SIMBAD Name:  </li>
<li>SIMBAD position (J2000): </li>
<xsl:variable name="vsim"><xsl:value-of select="SIMBAD_ID"/></xsl:variable>
<li><a href="http://simbad.harvard.edu/sim-id.pl?protocol=html&amp;Ident={$vsim}&amp;NbIdent=1&amp;Radius=10&amp;Radius.unit=arcmin">Query SIMBAD</a></li>
<li>Distance: </li>
<li>Diameter: </li>
<li>Distance modulus: </li>
<li>Extinction: </li>
<li><a href="http://cxc.harvard.edu/cgi-gen/cda/bibliography">References</a></li>
</ul>
</td><td>
<table border="0" bgcolor="#9999FF">
<tr class="tint">
  <td><img src="chandra_6min.jpg" width="140" height="140"/></td>
  <td><img src="2mass_6min.gif" width="140" height="140"/></td>
  <td><img src="dss_6min.gif" width="140" height="140"/></td></tr>
<tr class="tint"><th>Chandra</th><th>2MASS</th><th>DSS</th></tr>
</table></td></tr></table>
<br/>
<a href="Proc">View processing report</a><br/><br/>

<!-- OBS Details -->
<table border="1" bgcolor="#ffff99">
<tr><th colspan="6">Summary of Chandra Observations
<xsl:text>&#160;&#160;&#160;</xsl:text>
<a href="http://acis.mit.edu/cgi-bin/get-obsid?id={$vobs}">OBSCAT entry</a>
<xsl:text>&#160;&#160;&#160;</xsl:text>
<a href="http://cxc.harvard.edu/cgi-gen/cda/retrieve5.pl?obsid={$vobs}">Data files</a></th></tr>
<tr><th>Sequence</th>
    <th>OBS ID</th>
    <th>Instrument</th>
    <th>Exposure (ks)</th>
    <th>Date Observed</th>
    <th>Aimpoint (J2000)</th></tr>
<tr align="center">
    <td><xsl:value-of select="SEQ"/></td>
    <td><xsl:value-of select="OBSID"/></td>
    <td><xsl:value-of select="INST"/></td>
    <td><xsl:value-of select="EXPTIME"/></td>
    <td><xsl:value-of select="DATE"/></td>
    <td><xsl:value-of select="AIMPOINT"/></td></tr>
</table><br/>

<!-- SOURCES -->
<table border="1" rules="rows" cellspacing="0" cellpadding="5" bordercolor="white">
<tr><th colspan="7" class="h1">SOURCES
<xsl:text>&#160;&#160;&#160;</xsl:text>
<a href="download" class="download">text version</a></th></tr>
      <tr>
          <th class="h1"><a href="obs.html" class="h1link">ID</a></th>
          <th class="h1"><a href="obs_cnts.html" class="h1link">CNTS</a></th>
          <th class="h1">NH</th>
          <th class="h1">KT</th>
          <th class="h1">KT2</th>
          <th class="h1">CHI^2</th>
          <th class="h1"><a href="obs_bb.html" class="h1link">GLVARY</a></th>
      </tr>
      <xsl:apply-templates select="//SOURCE">
        <!--<xsl:if test="$sortcol='cnts'">-->
          <!--<xsl:sort select="NET_CNTS" order="descending" data-type="number"/>-->
          <xsl:sort select="RA" data-type="number"/>
          <!--<xsl:sort select="count(BBLOCKS/BBLOCKS_SIG/BBLOCKS_N)" order="descending" data-type="number"/>-->
        <!--</xsl:if>-->
      </xsl:apply-templates>
                   
    </table>
<br/>Last updated:<xsl:value-of select="created"/><br/>
<a href="../"><img src="../logo_tiny.png" alt="home"/></a>
<a href="../help.html"><img src="../logo_help.png" alt="help"/></a>
</center>

  </body></html>
</xsl:template>

<xsl:template match="SOURCE">
  <!--<xsl:sort select="SORTCOL" order="SORTDIR" data-type="number"/>-->
  <tr class="tint">
    <xsl:variable name="src"><xsl:value-of select="NAME"/></xsl:variable>
    <td><a class="src" href="{$src}/src.xml">
      CXOANC J<xsl:value-of select="NAME"/></a></td>
    <td><xsl:value-of select="NET_CNTS"/></td>
    <xsl:if test="count(SPECTRA/MODEL[@name='c_rs2'])=1">
      <xsl:apply-templates select="SPECTRA/MODEL[@name='c_rs2']"/>
    </xsl:if>
    <xsl:if test="count(SPECTRA/MODEL[@name='c_rs2'])=0">
      <xsl:apply-templates select="SPECTRA/MODEL[@name='c_rs']"/>
    </xsl:if>
    <xsl:if test="count(SPECTRA/MODEL[@name='c_rs'])=0">
      <xsl:apply-templates select="SPECTRA/MODEL[@name='cstat']"/>
    </xsl:if>
    <xsl:if test="count(SPECTRA/MODEL[@name='cstat'])=0">
      <td>-</td>
      <td>-</td>
      <td>-</td>
      <td>-</td>
    </xsl:if>
    <td><xsl:value-of select="GLVARY/GLVARY_INDEX"/></td>
  </tr>
</xsl:template>

<xsl:template match="MODEL">
    <td><xsl:value-of select="NH"/></td>
    <td><xsl:value-of select="KT"/></td>
    <xsl:if test="count(KT2)=1">
      <td><xsl:value-of select="KT2"/></td>
    </xsl:if>
    <xsl:if test="count(KT2)=0">
      <td>-</td>
    </xsl:if>
    <td><xsl:value-of select="CHI"/></td>
</xsl:template>

</xsl:stylesheet>
