PRO MATCH_OBSID, obsid, nominalRA, nominalDec

;=======================================================================;
; Matches 2MASS point source catalog sources to detected x-ray sources. ; 
; Requires a final modified input list from mk_psf_ellipse_correg.pro   ;
;  with 2 RA and Dec columns (make with ds9.                            ;
; Also requires a 2MASS psc table from GATOR (formatted) and a log file ;
;  from mk_psf_ellipse_correg.pro (mk_psf_ell_Creg.log)                 ;
;=======================================================================;
 
obsid  = strcompress(string(obsid), /remove_all)
     number = long(obsid)
     if (number lt 10) then obsidf = '0000'+obsid
     if (number ge 10) and (number lt 100) then obsidf = '000'+obsid
     if (number ge 100) and (number lt 1000) then obsidf = '00'+obsid
     if (number ge 1000) and (number lt 10000) then obsidf = '0'+obsid
     if (number ge 10000) then obsidf = obsid 


; to edit the gator input file to exclude extra columns type:
; awk '{print $1, $2, $3, $5, $6, $8, $9, $11, $12, $13, $14, $15, $16, $17}' obsid.tsv > obsid_mod.tsv  
; then remove the header and save again as obsid.tsv
; replace all 'null' entries with '9999' in xemacs (or some other way)

;================= Read in the X-Ray Source List: ======================
readcol, '/data/ANCHORS/YAXX/'+obsidf+'/sample.rdb', $
; readcol, '/data/ANCHORS/YAXX/LkHa101/src_psf_Cell_RA_Dec.reg', $
  x,x,raX, decX, format='(a,a,f,f)',skipline=2

   ra_X_hr = raX/360.*24.
   ra_X_deg = raX
   dec_X_deg= decX

;============Match the 2MASS catalog to X-Ray Catalog:==================

readcol, '/data/ANCHORS/YAXX/'+obsidf+'/fp_2mass.tbl', $
         raj2000, dej2000, jmag, e_jmag1, e_jmag, $
         hmag, e_hmag1, e_hmag, kmag, e_kmag1, e_kmag, $
         Qflg, Rflg, Bflg, Cflg, Xflg, Aflg, dist,ang, $
         format='(F,F,F,f,f,f,F,F,F,F,F,A,A,A,A,I,I,f,f)', $
         skipline=9
print,raj2000(0),raj2000(1)
print,jmag(0),jmag(1)
print,dist(0),dist(1)

  ra_2mass_hr=raj2000/360.*24.
  dec_2mass_deg=dej2000

  matchTM=lonarr(n_elements(raX))
  mdiffTM=fltarr(n_elements(raX))
  gcirc,1,ra_X_hr,dec_X_deg,nominalRA/360.*24.,nominalDec,offax  
  for i=0,n_elements(raX)-1 do begin
    gcirc,1,ra_X_hr[i],dec_X_deg[i],ra_2mass_hr,dec_2mass_deg,diff
    mdiffTM[i]=min(diff,m)
    matchTM[i]=m
  endfor

  raj2000 = double(raj2000[matchTM])
  dej2000 = double(dej2000[matchTM])
  jmag    = jmag[matchTM]
  e_jmag  = e_jmag[matchTM]
  hmag    = hmag[matchTM]
  e_hmag  = e_hmag[matchTM]
  kmag    = kmag[matchTM]
  e_kmag  = e_kmag[matchTM]
  Qflg    = Qflg[matchTM]
  Rflg    = Rflg[matchTM]
  Bflg    = Bflg[matchTM]
  Cflg    = Cflg[matchTM]
  Xflg    = Xflg[matchTM]
  Aflg    = Aflg[matchTM]
  src_id  = indgen(n_elements(matchTM))+1

;================Read in the X-ray file with offax min, etc.============
;readcol, '/data/ANCHORS/YAXX/LkHa101/mk_psf_ell_Creg.log', $
;readcol, '/data/ANCHORS/YAXX/'+obsidf+'/LOG/mk_psf_ell_Creg.log', $
          ;xx,yy,r,offax_min,ang, col1,col2, format='(f,f,f,f,f,f,f)'

tk=sort(offax)
offax_s  = offax[tk]
mdiffTM_s= mdiffTM[tk]
y_cutoff=.07*(offax_s/100.)^2+2.

;********  PLOT ********
;set_plot, 'ps'
;device, filename='/data/ANCHORS/YAXX/'+obsidf+'/offset_vs_offaxis.ps'
;
;------------2MASS Match plot:------------------
;
;plot, offax, mdiffTM, psym=4, symsize=1.2, $
;      title='2MASS Matching Offset as a function of Off-axis Position [all sources]', $
;      xr=[0.,600.],yr=[0.,5.],$
;      xtitle='Off-axis position ["]', ytitle='Offset ["]'
;oplot, offax, mdiff_tm, psym=4, symsize=1.8
;y_cutoff=.07*(offax_s/100.)^2+2.
;oplot, offax_s, y_cutoff, line=2
;xyouts, 30.,4.,'Stars designate all sources'+$
;              '!CDiamonds designate only those sources,'+$
;              '!C   for which Optical counterparts were identified', $
;              charsize=0.8
;device,/close
;-----------------

j=0
pickTM_cutoff=indgen(n_elements(offax))
pickTM_cutoff[*] = 9999

for i=0, n_elements(offax)-1 do begin
    if mdiffTM[i] le .07*(offax[i]/100.)^2+2. then begin
;   if (mdiffTM_s[i] lt y_cutoff[i]) then begin
       pickTM_cutoff[j]=i
       j=j+1
   endif 
endfor
pk=where(pickTM_cutoff ne 9999)
pTM_cutoff=pickTM_cutoff[pk]
offaxTM_cutoff=offax_s[pTM_cutoff]
mdiffTM_cutoff=mdiffTM_s[pTM_cutoff]

;plot, offaxTM_cutoff, mdiffTM_cutoff, psym=2, symsize=0.8,$
;      title='Matching Offset as a function of Off-axis Position [good 2Mass matches]',$
;      xtitle='Off-axis position ["]', ytitle='Offset ["]'
;oplot, offax_s, y_cutoff, line=2
;xyouts, 50.,3.5,'The dashed line designates the limit imposed on maximum offsets' +$
;              '!Cto identify trustworthy matches'+ $
;              '!C  An analytical expression offset!U"!Lmax!N=0.07*(off-axis!U"!N/100)!U2!N+2', $
;               charsize=0.8  
;
;plot, (hmag[pTM_cutoff]-5.*alog10(241.)-0.323) - (kmag[pTM_cutoff]-5.*alog10(241.)-0.206), $
;      (jmag[pTM_cutoff]-5.*alog10(241.)-0.505) - (hmag[pTM_cutoff]-5.*alog10(241.)-0.323), $
;       xtitle='H-K', ytitle='J-H', title='2MASS Color-Color Diagram for obsid'+obsid+' X-ray Sources', $
;       psym=2, symsize=0.8

;plot, (hmag[pTM_cutoff]-5.*alog10(241.)-0.323) - (kmag[pTM_cutoff]-5.*alog10(241.)-0.206), $
;      (jmag[pTM_cutoff]-5.*alog10(241.)-0.505) - (hmag[pTM_cutoff]-5.*alog10(241.)-0.323), $
;       xr=[-0.1, 1.3], yr=[-0.1, 2.], /xstyle, /ystyle, psym=2, symsize=0.8, $
;       xtitle='H-K', ytitle='J-H', title='2MASS Color-Color Diagram for obsid'+obsid+' X-ray Sources'

;errcut = where((e_kmag[pTM_cutoff] le 0.1 ) and (e_hmag[pTM_cutoff] lt 900) and (e_jmag[pTM_cutoff] lt 900))
;plot, (hmag[pTM_cutoff[errcut]]-5.*alog10(241.)-0.323) - (kmag[pTM_cutoff[errcut]]-5.*alog10(241.)-0.206), $
;      (jmag[pTM_cutoff[errcut]]-5.*alog10(241.)-0.505) - (hmag[pTM_cutoff[errcut]]-5.*alog10(241.)-0.323), $
;       xr=[-0.1, 1.3], yr=[-0.1, 2.], /xstyle, /ystyle, psym=2, symsize=0.8, $
;       xtitle='H-K', ytitle='J-H', title='2MASS Color-Color Diagram for h Persei X-ray Sources' + $
;                                         '!C(only for those sources where K-band error < 0.1)'

;loadct, 2     ;!!!!! select
set_plot, 'ps'
;device, filename='/data/ANCHORS/YAXX/LkHa101/2MASS_cctracks_labels.ps'
device, filename='/data/ANCHORS/YAXX/'+obsidf+'/2MASS_cctracks_nolabels.ps'
;device, /color   ; !!!! select

errcut = where((e_kmag[pTM_cutoff] le 5.1 ) and (e_hmag[pTM_cutoff] lt 900) and (e_jmag[pTM_cutoff] lt 900))
x_values=(hmag[pTM_cutoff[errcut]]) - (kmag[pTM_cutoff[errcut]])
y_values=(jmag[pTM_cutoff[errcut]]) - (hmag[pTM_cutoff[errcut]])
x_errors=sqrt((e_hmag[pTM_cutoff[errcut]])^2. + (e_kmag[pTM_cutoff[errcut]])^2.)
y_errors=sqrt((e_jmag[pTM_cutoff[errcut]])^2. + (e_hmag[pTM_cutoff[errcut]])^2.)
tot_errors=sqrt(x_errors^2. + y_errors^2.)

   A = FIndGen(16) * (!PI*2/16.)
   UserSym, cos(A), sin(A), /fill
   varsize=dblarr(n_elements(tot_errors))

plot,  x_values, y_values, $
       xr=[-0.1, 0.8], yr=[-0.1, 1.3], /xstyle, /ystyle, psym=3, color=1, symsize=0.2, $
       xtitle='H-K', ytitle='J-H', title='2MASS Color-Color Diagram for obsid'+obsid+' X-ray Sources' 

   for k=1, n_elements(x_values)-1 do begin

   varsize[k]=double(1/(10.*tot_errors[k])-0.4)
  
   xopl=[x_values[k], 3000.]
   yopl=[y_values[k], 3000.] 
   oplot, xopl, yopl, psym=8, symsize=varsize[k], color=240
   oplot, xopl, yopl, psym=3, color=1
   src_number=strcompress(src_id[pTM_cutoff[errcut[k]]],/remove_all)
;   xyouts, xopl, yopl, src_number, color=1, charsize=0.8
   endfor

;errplot, x_values, y_values + y_errors, y_values - y_errors
;for i=0, n_elements(x_values)-1 do oplot, [x_values[i]-x_errors[i], x_values[i]+x_errors[i]], [y_values[i], y_values[i]]
;for i=0, n_elements(x_values)-1 do oplot, [x_values[i]-x_errors[i], x_values[i]+x_errors[i]], [y_values[i]-y_errors[i], y_values[i]+y_errors[i]]



;CTTS loci from Meyer \e 1997
HMKC=indgen(200)
hmkc=hmkc/100.
jmkc=0.58*hmkc+.52
oplot, hmkc(17:*),jmkc(17:*), lines = 3, thick = 3;
;Reddening vector
Av = indgen(10)
Av = Av/5.  ;---10 magnitudes of extinction
EJMH = 0.11*Av
EHMK = 0.065*Av
oplot, EHMK, EJMH+1, thick = 2, color=1
oplot, [EHMK(9),0.083], [EJMH(9)+1, 1.175], thick = 2
oplot, [EHMK(9),0.10], [EJMH(9)+1, 1.14], thick = 2

xyouts, 0.0, 0.9,'!3 Av=1.0',ori=40,size=2, charthick=3

;Edge line 1
Av = indgen(400)
Av = Av/10.  ;---40 magnitudes of extinction
EJMH = 0.11*Av
EHMK = 0.065*Av
oplot, EHMK-0.05, EJMH-0.15, lines = 2, thick = 3
oplot, EHMK+.168, EJMH+.61, lines = 2, thick = 3
oplot, EHMK+2, EJMH+1.68, lines = 2, thick = 3


;KOORNNEEF 1983 - GIANTS
gkoornspt =[ 43,  48,  50,  51,  52,  53,  54,  55,  60,   61,   62,   63,  64,   65,   66]
gkoornjmk =[.56, .59, .64, .68, .72, .80, .88, .96, .97, 1.01, 1.04, 1.10,1.16, 1.24, 1.30]
gkoornhmk =[.11, .12, .13, .14, .14, .16, .18, .20, .21, 0.21, 0.23, 0.25,0.27, 0.31, 0.35]

;KOORNNEEF 1983 - MS
koornspt =[   7,    9,  9.5,   10, 10.5,   11,   12,   13,   14,   15,   16, 17,   18,   19, 20]
koornjmk =[-.21, -.19, -.18, -.17, -.15, -.14, -.13, -.11, -.10, -.08, -.07, -.05, -.04, -.02, .01]
koornhmk =[-.05, -.05, -.05, -.05, -.04, -.04, -.04, -.03, -.03, -.02, -.02, -.02, -.01, -.01, 0.0]
koornspt =[koornspt,  21,  22,  23,  24,  25,  26,  27,  28,  29,  30,  32, 35,   38,  40, 43]
koornjmk =[koornjmk, .02, .04, .05, .07, .09, .10, .12, .14, .17, .20, .24,.26, .29, .31, .37]
koornhmk =[koornhmk, .00, .01, .01, .02, .02, .02, .02, .03, .04, .04, .05, .06, .06, .07, .08]
koornspt =[koornspt,  48,  50,  51,  52,  53,  54,  55,  60,  61,  62,  63, 64,   65,  66,  67, 68]
koornjmk =[koornjmk, .41, .47, .54, .62, .67, .72, .77, .83, .86, .89, .92, .90, .90, .88, .89, .90]
koornhmk =[koornhmk, .09, .10, .11, .13, .14, .15, .16, .18, .19, .21, .26,.28,  .29, .30, .31, .33]

;COORECTION FROM LADA AND ADAMS 1992

jmh = Koornjmk - Koornhmk
jmhcorr =  (0.92*jmh)-0.005
hmkcorr =( 0.912*Koornhmk)-0.009


tit = '!7r !17 Orionis: 2MASS colors of X-ray sources'
tit = '!17 RCW 38: IR colors of X-ray sources'
;tit = '!17 RCW 38: IR colors of non X-ray sources'
tit = ' '
oplot,hmkcorr,jmhcorr, thick=3

device,/close
;stop
;return

set_plot, 'ps'
device, /color
device, /landscape
device, filename='/data/ANCHORS/YAXX/'+obsidf+'/2MASS_errors.ps'
; device, filename='/data/ANCHORS/YAXX/LkHa101/2MASS_errors.ps'

jerr_hist=HISTOGRAM(e_jmag[pTM_cutoff], binsize=0.01)
plot, jerr_hist, xr=[0.,20], psym=10, color=1, $
   xtitle="j-magnitude error [mag * 100]", ytitle = "number of sources in the sample"

herr_hist=HISTOGRAM(e_hmag[pTM_cutoff], binsize=0.01)
plot, herr_hist, xr=[0.,20], psym=10, color=1,$
   xtitle="h-magnitude error [mag * 100]", ytitle = "number of sources in the sample"

kerr_hist=HISTOGRAM(e_kmag[pTM_cutoff], binsize=0.01)
plot, kerr_hist, xr=[0.,20], psym=10,color=1, $
   xtitle="k-magnitude error [mag * 100]", ytitle = "number of sources in the sample"

device,/close
;-------------

set_plot, 'ps'
device, filename='/data/ANCHORS/YAXX/'+obsidf+'/JvsJmK_10_label.ps'
;device, filename='/data/ANCHORS/YAXX/LkHa101/JvsJmK_10_label.ps'
device, /color
;!p.multi=[0,2,1]
errcut = where((e_kmag[pTM_cutoff] le 0.1 ) and (e_hmag[pTM_cutoff] lt 900) and (e_jmag[pTM_cutoff] lt 900))
x_values=(jmag[pTM_cutoff[errcut]]) - (kmag[pTM_cutoff[errcut]])
y_values=(kmag[pTM_cutoff[errcut]])

plot,  x_values, y_values, /xstyle, /ystyle, psym=2, symsize=0.8, yr=[15.,12.],charsize=0.8, xthick=1, ythick=1, charthick=1,$
       xtitle='j-k', ytitle='k', title='2MASS Color-Magnitude Diagram!C for obsid'+obsid+' X-ray Sources!C(10% max. errors)'
   oplot, x_values, y_values, psym=2, symsize=0.8, color=240 
   oplot, x_values, y_values, psym=3, color=1
       for l=0,n_elements(x_values)-1 do begin
       src_number=strcompress(src_id[pTM_cutoff[errcut[l]]],/remove_all)
       xyouts, x_values[l]+0.01, y_values[l], src_number, charsize=0.7
       endfor

plot,  x_values, y_values, /xstyle, /ystyle, psym=3, symsize=0.8, color=1, yr=[15.,7.],charsize=0.8, xthick=1, ythick=1, charthick=1,$
       xtitle='j-k', ytitle='k', title='2MASS Color-Magnitude Diagram!C for obsid'+obsid+' X-ray Sources!C(10% max. errors)'
    oplot, x_values, y_values, psym=2, symsize=0.8, color=240 
    oplot, x_values, y_values, psym=3, color=1
       for l=0,n_elements(x_values)-1 do begin
       src_number=strcompress(src_id[pTM_cutoff[errcut[l]]],/remove_all)
       xyouts, x_values[l]+0.01, y_values[l], src_number, charsize=0.7, color=1
       endfor
 
device,/close
;stop
;return

; ***********************

for i=0, n_elements(RaX)-1 do begin

;    if pickTM_cutoff[i] ne 9999 then begin
    if mdiffTM[i] le .07*(offax[i]/100.)^2+2. then begin
          mdiffTMs  = strcompress( mdiffTM[i] , /remove_all)
          raj2000tm = strcompress( raj2000[i] , /remove_all)
          dej2000tm = strcompress( dej2000[i] , /remove_all)
          jmagtm    = strcompress( jmag[i] , /remove_all)
          e_jmagtm  = strcompress( e_jmag[i] , /remove_all)
          hmagtm    = strcompress( hmag[i] , /remove_all)
          e_hmagtm  = strcompress( e_hmag[i] , /remove_all)
          kmagtm    = strcompress( kmag[i] , /remove_all)
          e_kmagtm  = strcompress( e_kmag[i] , /remove_all)
          Qflgtm    = Qflg[i]
          Rflgtm    = Rflg[i]
          Bflgtm    = Bflg[i]
          Cflgtm    = Cflg[i]
          Xflgtm    = "  "+strcompress( Xflg[i] , /remove_all)
          Aflgtm    = "  "+strcompress( Aflg[i] , /remove_all)
          
     endif else begin
          mdiffTms  =  "  ----  "
          raj2000tm =  "   ----   ";    +strcompress(9999,/remove_all)
          dej2000tm =  "   ----   ";    +strcompress(9999,/remove_all)
          jmagtm    =  " ---- ";        +strcompress(9999,/remove_all)
          e_jmagtm  =  " ---- ";        +strcompress(9999,/remove_all)
          hmagtm    =  " ---- ";        +strcompress(9999,/remove_all)
          e_hmagtm  =  " ---- ";	+strcompress(9999,/remove_all)
          kmagtm    =  " ---- ";	+strcompress(9999,/remove_all)
          e_kmagtm  =  " ---- ";	+strcompress(9999,/remove_all)
          Qflgtm    = strcompress(999,/remove_all)
          Rflgtm    = strcompress(999,/remove_all)
          Bflgtm    = strcompress(999,/remove_all)
          Cflgtm    = strcompress(999,/remove_all)
          Xflgtm    = strcompress(999,/remove_all)
          Aflgtm    = strcompress(999,/remove_all)
     endelse

;     ----------------------
  close, 3

  if mdiffTM[i] le .07*(offax[i]/100.)^2+2. then begin

  openw, 3, '/data/ANCHORS/YAXX/'+obsidf+'/Data/obs'+obsid+'/src' + strcompress((i+1),/remove_all) + '/tmc.match'
;  openw, 3, '/data/ANCHORS/YAXX/LkHa101/Data/obs54289/src' + strcompress((i+1),/remove_all) + '/tmc.match'
  printf, 3, "offax.    ang. X-ray_ra   X-ray_dec  tmass_ra   tmass_dec   offset j_mag  j_mag_e h_mag h_mag_e k_mag k_mag_e Q_f R_f B_f C_f X_f A_f"   
  printf, 3, offax[i], 0, raX[i], decX[i], raj2000tm, dej2000tm, mdiffTMs, JmagTm,e_JmagTm, HmagTm,e_HmagTm, KmagTm,e_KmagTm, $
             Qflgtm, Rflgtm, Bflgtm, Cflgtm, Xflgtm, Aflgtm, $
             format='(F8.4," ",F6.2," ",A10," ",A10," ",A10," ",A10," ",A8," ",A6," ",A6," ",A6," ",A6," ",A6," ",A6," ",A3," ",A3," ",A3," ",A3," ",A3," ",A3,/)'
  close, 3
  endif

endfor


end
