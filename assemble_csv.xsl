<?xml version="1.0"?><!--prod-imp.xsl-->
<!--XSLT 1.0 - http://www.CraneSoftwrights.com/training -->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:strip-space elements="SOURCE"/>
<xsl:output method="text"/>
  <xsl:param name="vsect">banner2</xsl:param>
  <xsl:param name="vobs">VOBS</xsl:param>
  <xsl:param name="vsrcid">VSRCID</xsl:param>
<!-- can not use param/var in match -->
<!-- here we'll assume we're using indiv. src.xml -->
<xsl:template match="//SOURCE[1]">
  <xsl:value-of select="@id"/>
  ,<xsl:value-of select="RA/@str"/>
  ,<xsl:value-of select="DEC/@str"/>
  <xsl:if test="$vsect='top'">
    ,<xsl:value-of select="CNTS"/>
    ,<xsl:value-of select="NET_CNTS"/>
    ,<xsl:value-of select="NET_FLUX"/>
    ,<xsl:value-of select="NET_FLUX_ERR"/>
    ,<xsl:value-of select="EXP"/>
    ,<xsl:value-of select="OFF_AX"/>
    ,<xsl:value-of select="CCD_ID"/>
    ,<xsl:value-of select="format-number(Q25,'##.###')"/>
    ,<xsl:value-of select="format-number(Q25_err,'##.###')"/>
    ,<xsl:value-of select="format-number(Q50,'##.###')"/>
    ,<xsl:value-of select="format-number(Q50_err,'##.###')"/>
    ,<xsl:value-of select="format-number(Q75,'##.###')"/>
    ,<xsl:value-of select="format-number(Q75_err,'##.###')"/>
  </xsl:if>
  <xsl:if test="$vsect='bblocks'">
    <xsl:apply-templates select="BBLOCKS"/>
  </xsl:if>
  <xsl:if test="$vsect='lc'">
    <xsl:apply-templates select="GLVARY"/>
  </xsl:if>
  <xsl:if test="$vsect='spec'">
    <xsl:apply-templates select="SPECTRA"/>
  </xsl:if>
  <xsl:if test="$vsect='apec'">
    <xsl:apply-templates select="ASPECTRA"/>
  </xsl:if>
  <xsl:if test="$vsect='ir'">
    <xsl:variable name="IR" select="document('/tmp/2mass.xml')"/>
    ,<xsl:value-of select="RA"/>
    ,<xsl:value-of select="DEC"/>
    ,<xsl:value-of select="$IR//SOURCE/tmass_ra"/>
    ,<xsl:value-of select="$IR//SOURCE/tmass_dec"/>
    ,<xsl:value-of select="$IR//SOURCE/offset"/>
    ,<xsl:value-of select="$IR//SOURCE/j_mag"/>
    ,<xsl:value-of select="$IR//SOURCE/j_mag_e"/>
    ,<xsl:value-of select="$IR//SOURCE/h_mag"/>
    ,<xsl:value-of select="$IR//SOURCE/h_mag_e"/>
    ,<xsl:value-of select="$IR//SOURCE/k_mag"/>
    ,<xsl:value-of select="$IR//SOURCE/k_mag_e"/>
    ,<xsl:value-of select="$IR//SOURCE/Q_f"/>
  </xsl:if>
</xsl:template>

<xsl:template match="SPECTRA">
  <xsl:apply-templates select="MODEL[@name='cstat']"/>
  <xsl:apply-templates select="MODEL[@name='c_rs']"/>
  <xsl:apply-templates select="MODEL[@name='c_rs2']"/>
  <xsl:apply-templates select="MODEL[@name='c_rs2a']"/>
  <xsl:apply-templates select="MODEL[@name='c_ap']"/>
  <xsl:apply-templates select="MODEL[@name='c_ap2']"/>
  <xsl:apply-templates select="MODEL[@name='c_ap2a']"/>
</xsl:template>

<xsl:template match="ASPECTRA">
  <xsl:apply-templates select="MODEL[@name='c_ap']"/>
  <xsl:apply-templates select="MODEL[@name='c_ap2']"/>
  <xsl:apply-templates select="MODEL[@name='c_ap2a']"/>
</xsl:template>

<xsl:template match="MODEL">
    ,<xsl:value-of select="NH"/>
    ,<xsl:value-of select="NH_ERR"/>
    ,<xsl:value-of select="KT"/>
    ,<xsl:value-of select="KT_ERR"/>
    ,<xsl:value-of select="KT2"/>
    ,<xsl:value-of select="KT2_ERR"/>
    ,<xsl:value-of select="ABUND"/>
    ,<xsl:value-of select="ABUND_ERR"/>
    ,<xsl:value-of select="FLUX"/>
    ,<xsl:value-of select="KT_FLUX"/>
    ,<xsl:value-of select="KT2_FLUX"/>
    ,<xsl:value-of select="CHI"/>
    ,<xsl:value-of select="DOF"/>
</xsl:template>

<xsl:template match="BBLOCKS">
  <xsl:apply-templates select="BBLOCKS_SIG/BBLOCKS_N"/>
</xsl:template>

<xsl:template match="LC">
  <xsl:apply-templates select="GLVARY"/>
  <xsl:apply-templates select="BBLOCKS_SIG/BBLOCKS_N"/>
</xsl:template>

<xsl:template match="BBLOCKS_N">
    ,<xsl:value-of select="@n"/>
    ,<xsl:value-of select="BBLOCKS_RATE"/>
    ,<xsl:value-of select="BBLOCKS_ERR"/>
    ,<xsl:value-of select="BBLOCKS_DT"/>
</xsl:template>

<xsl:template match="GLVARY">
    ,<xsl:value-of select="GLVARY_ODDS"/>
    ,<xsl:value-of select="GLVARY_PROB"/>
    ,<xsl:value-of select="GLVARY_INDEX"/>
</xsl:template>

<xsl:template match="//created"/>

</xsl:stylesheet>
