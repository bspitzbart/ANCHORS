PRO MK_PSF_ELLIPSE_CORREG

readcol,'calc_theta_phi.out',src,x,y,offax_min,ang,ra,dec,chip, $
        format='f,f,f,f,f,f,f,f'

ell=mrdfits('/data/aaron/YAXX/05407_old/Data/hrmaD1996-12-20hrci_ell_ecf_N0003.fits',1)
cir=mrdfits('/data/aaron/YAXX/05407_old/Data/hrmaD1996-12-20hrci_ecf_N0002.fits',1)
iecf=where(ell(0).ecf eq 0.90)
ienergy=where(ell(0).energy eq 1.0)

openw, ounit, 'xxx1.reg', /get_lun
openw, bunit, 'xxx2.reg', /get_lun
openw, lunit, 'xxx3.log', /get_lun

;openw, ounit, 'src_psf_Iell.reg', /get_lun
;openw, bunit, 'bkg_psf_Iell.reg', /get_lun
;openw, lunit, 'mk_psf_Iell_reg.log', /get_lun

for i=0,n_elements(x)-1 do begin

 ; select circles or ellipses based on offax_min
  if (offax_min(i) gt 4) then begin
    mat=ell
    ellipse=1
  endif else begin
    mat=cir
    ellipse=0
  endelse

  ; calculate off-axis angle
  ;offax_min=sqrt((y(i)-4096.5)^2+(x(i)-4096.5)^2)*0.492/60.0
  ; find closest theta
  dtheta=abs(offax_min(i)-mat(0).theta)
  itheta=where(dtheta eq min(dtheta))

  ; find closest phi - will interpolate because parameterization is coarse
  dphi=ang(i)-mat(0).phi
  ephi=dphi(where(dphi ge 0))  ; select closest phi less than angle
  iphi=where(dphi eq min(ephi))
  phi_lo=mat(0).phi(iphi)

  if (ellipse) then begin
    a_lo=mat(0).sma(iecf(0),itheta(0),iphi(0),ienergy(0))
    b_lo=mat(0).smb(iecf(0),itheta(0),iphi(0),ienergy(0))
    p_lo=(mat(0).pa(iecf(0),itheta(0),iphi(0),ienergy(0))+180.) mod 180
  endif else begin
    r_lo=mat(0).radius(iecf(0),itheta(0),iphi(0),ienergy(0))
  endelse

  ; select closest phi greater than ang
  iphi=(iphi+1) mod n_elements(mat(0).phi)
  phi_hi=mat(0).phi(iphi)
  if (iphi(0) eq 0) then phi_hi=360

  if (ellipse) then begin
    a_hi=mat(0).sma(iecf(0),itheta(0),iphi(0),ienergy(0))
    b_hi=mat(0).smb(iecf(0),itheta(0),iphi(0),ienergy(0))
    p_hi=(mat(0).pa(iecf(0),itheta(0),iphi(0),ienergy(0))+180.) mod 180
  endif else begin
    r_hi=mat(0).radius(iecf(0),itheta(0),iphi(0),ienergy(0))
  endelse

  ; interpolate by phi
  if (ellipse) then begin
    a=(((ang(i)-phi_lo)*(a_hi-a_lo))/(phi_hi-phi_lo))+a_lo
    b=(((ang(i)-phi_lo)*(b_hi-b_lo))/(phi_hi-phi_lo))+b_lo
    p=(((ang(i)-phi_lo)*(p_hi-p_lo))/(phi_hi-phi_lo))+p_lo
    a=a/0.492 
    b=b/0.492  ; convert back to pixels
    reg=strcompress("ellipse("+ $
                    string(x(i),format='(F8.3)')+","+ $
                    string(y(i),format='(F8.3)')+","+ $
                    string(a,format='(F7.3)')+","+ $
                    string(b,format='(F7.3)')+","+ $
                    string(p,format='(F6.2)')+")",/remove_all)
    printf, lunit,x(i),y(i),p,offax_min(i),ang(i), $
                    mat(0).theta(itheta(0)),mat(0).phi(iphi(0))
  endif else begin
    r=(((ang(i)-phi_lo)*(r_hi-r_lo))/(phi_hi-phi_lo))+r_lo
    r=r*2.0/0.492
    reg=strcompress("circle("+ $
                    string(x(i),format='(F8.3)')+","+ $
                    string(y(i),format='(F8.3)')+","+ $
                    string(r,format='(F7.3)')+")",/remove_all)
    printf, lunit,x(i),y(i),r,offax_min(i),ang(i), $
                    mat(0).theta(itheta(0)),mat(0).phi(iphi(0))
  endelse
  ; select custom,common background region
  if (chip(i) eq 0 and offax_min(i) le 4) then $
    bkg="circle(3729.5,4389.5,62.241727)"
  if (chip(i) eq 0 and offax_min(i) gt 4) then $
    bkg="circle(3449.5,5165.5,99.556482)"
  if (chip(i) eq 1 and offax_min(i) le 4) then $
    bkg="circle(3897.5,4069.5,71.468198)"
  if (chip(i) eq 1 and offax_min(i) gt 4) then $
    bkg="circle(3073.5,3493.5,148.27731)"
  if (chip(i) eq 2 and offax_min(i) le 4) then $
    bkg="circle(4865.5,4861.5,107.8508)"
  if (chip(i) eq 2 and offax_min(i) gt 4) then $
    bkg="circle(4313.5,4197.5,81.290023)"
  if (chip(i) eq 3 and offax_min(i) le 4) then $
    bkg="circle(4217.5,3869.5,90.696388)"
  if (chip(i) eq 3 and offax_min(i) gt 4) then $
    bkg="circle(4633.5,3157.5,126.25253)"
  if (chip(i) eq 6) then $
    bkg="circle(6206.5,5018.5,80)"
  if (chip(i) eq 7) then $
    bkg="circle(5914.5,3402.5,80)"


  ; use my formula instead
  if (ellipse) then begin
    ang1=double(atan(double(y(i)-4096.5)/double(x(i)-4096.5)))*360.0/2.0/!pi
    ;if (ang1 lt 90.0) then ang1=ang1+90.0
    ;if (ang1 gt 270.0) then ang1=ang1-90.0
    p=95.4+0.47*ang1
    if (x(i) lt 4096.5) then p=p+90.0
;    p=(p+90.) mod 180.
    a=1.97-0.22*offax_min(i)+0.15*offax_min(i)^2
    b=2.03-0.13*offax_min(i)+0.08*offax_min(i)^2
    a=a/0.492  ; convert back to pixels
    b=b/0.492  ; convert back to pixels
    reg=strcompress("ellipse("+ $
                  string(x(i),format='(F8.3)')+","+ $
                  string(y(i),format='(F8.3)')+","+ $
                  string(a*1.5,format='(F7.3)')+","+ $
                  string(b*1.5,format='(F7.3)')+","+ $
                  string(p,format='(F6.2)')+")",/remove_all)
  endif ;if (ellipse) then begin

  printf, ounit, reg
  printf, bunit, bkg
endfor
free_lun, ounit
free_lun, bunit
free_lun, lunit

;==================
readcol, 'xyma.dat', x,y,MA, format='f,f,f' ; MA=major axis
eventfile='../Data/obs635/acis_dstrk_evt2.fits'
eventfile=STRCOMPRESS(eventfile, /remove_all)
aperture='../Data/obs635/ApertureImages/aperture'
aperture=STRCOMPRESS(aperture, /remove_all)

regionsarray=strarr(1,n_elements(x))
close, 1
openr, 1, 'src_psf_ell.reg' 
readf, 1, regionsarray

for i=0, n_elements(x)-1 do begin
index=i+1
index=STRCOMPRESS(index, /remove_all)
regionsarrayS=STRCOMPRESS(regionsarray[i], /remove_all)

xmin=fix(x[i]-100., type=4)
 xmin=STRCOMPRESS(xmin, /remove_all)
xmax=fix(x[i]+100., type=4)
 xmax=STRCOMPRESS(xmax, /remove_all)
ymin=fix(y[i]-100., type=4)
 ymin=STRCOMPRESS(ymin, /remove_all)
ymax=fix(y[i]+100., type=4)
 ymax=STRCOMPRESS(ymax, /remove_all)

quote='"'
spawn, '/soft/ciao3.4/bin/dmcopy ' + quote + eventfile + '[sky=' + regionsarrayS + '][bin x=' +$
       xmin + ':' + xmax + ':1,y=' + ymin + ':' + ymax + ':1]'+quote+$
       aperture + index + '.fits clobber=yes mode=h'

endfor

 xcenter=fltarr(n_elements(x))
 ycenter=fltarr(n_elements(y)) 
 xxbar=fltarr(n_elements(x))
 yybar=fltarr(n_elements(x))
 for i=0, n_elements(x)-1 do begin
  index=i+1
  index=STRCOMPRESS(index, /remove_all)
  array=mrdfits(aperture+index+'.fits')

  skyback=0.1
  xbar=0
  ybar=0
  counts=0
  if (ma[i] ge 100) then ma[i]=99
  CENTROD, array, 100,100, MA[i], MA[i]+5., MA[i]+15., skyback, xbar, ybar, counts
  xcenter[i]=x[i]+(xbar-100.)
  ycenter[i]=y[i]+(ybar-100.)
  xxbar[i]=xbar
  yybar[i]=ybar
 endfor
close, 1
;==================repeat the original procedure for corrected x,y


openw, ounit, 'src_psf_Cell.reg', /get_lun
openw, bunit, 'bkg_psf_Cell.reg', /get_lun
openw, lunit, 'mk_psf_ell_Creg.log', /get_lun

for i=0,n_elements(x)-1 do begin
  ; select circles or ellipses based on offax_min
  if (offax_min(i) gt 4) then begin
    mat=ell
    ellipse=1
  endif else begin
    mat=cir
    ellipse=0
  endelse

  ; find closest theta
  dtheta=abs(offax_min(i)-mat(0).theta)
  itheta=where(dtheta eq min(dtheta))

  ; find closest phi - will interpolate because parameterization is coarse
  dphi=ang(i)-mat(0).phi
  ephi=dphi(where(dphi ge 0))  ; select closest phi less than angle
  iphi=where(dphi eq min(ephi))
  phi_lo=mat(0).phi(iphi)

  if (ellipse) then begin
    a_lo=mat(0).sma(iecf(0),itheta(0),iphi(0),ienergy(0))
    b_lo=mat(0).smb(iecf(0),itheta(0),iphi(0),ienergy(0))
    p_lo=(mat(0).pa(iecf(0),itheta(0),iphi(0),ienergy(0))+180.) mod 180
  endif else begin
    r_lo=mat(0).radius(iecf(0),itheta(0),iphi(0),ienergy(0))
  endelse

  ; select closest phi greater than ang
  iphi=(iphi+1) mod n_elements(mat(0).phi)
  phi_hi=mat(0).phi(iphi)
  if (iphi(0) eq 0) then phi_hi=360

  if (ellipse) then begin
    a_hi=mat(0).sma(iecf(0),itheta(0),iphi(0),ienergy(0))
    b_hi=mat(0).smb(iecf(0),itheta(0),iphi(0),ienergy(0))
    p_hi=(mat(0).pa(iecf(0),itheta(0),iphi(0),ienergy(0))+180.) mod 180
  endif else begin
    r_hi=mat(0).radius(iecf(0),itheta(0),iphi(0),ienergy(0))
  endelse

  ; interpolate by phi
  if (ellipse) then begin
    a=(((ang(i)-phi_lo)*(a_hi-a_lo))/(phi_hi-phi_lo))+a_lo
    b=(((ang(i)-phi_lo)*(b_hi-b_lo))/(phi_hi-phi_lo))+b_lo
    p=(((ang(i)-phi_lo)*(p_hi-p_lo))/(phi_hi-phi_lo))+p_lo
    a=a/0.492  ; convert back to pixels 
    b=b/0.492  ; convert back to pixels
    reg=strcompress("ellipse("+ $
                    string(xcenter(i),format='(F8.3)')+","+ $
                    string(ycenter(i),format='(F8.3)')+","+ $
                    string(a,format='(F7.3)')+","+ $
                    string(b,format='(F7.3)')+","+ $
                    string(p,format='(F6.2)')+")",/remove_all)
    printf, lunit,xcenter(i),ycenter(i),p,offax_min(i),ang(i), $
                    mat(0).theta(itheta(0)),mat(0).phi(iphi(0)), $
            format='(f9.3,1x,f9.3,1x,f9.4,1x,f6.2,1x,f6.2,1x,f7.3,1x,f5.1)' 
  endif else begin
    r=(((ang(i)-phi_lo)*(r_hi-r_lo))/(phi_hi-phi_lo))+r_lo
    r=r*2.0/0.492
    reg=strcompress("circle("+ $
                    string(xcenter(i),format='(F8.3)')+","+ $
                    string(ycenter(i),format='(F8.3)')+","+ $
                    string(r,format='(F7.3)')+")",/remove_all)
    printf, lunit,xcenter(i),ycenter(i),r,offax_min(i),ang(i), $
                    mat(0).theta(itheta(0)),mat(0).phi(iphi(0)), $
            format='(f9.3,1x,f9.3,1x,f9.4,1x,f6.2,1x,f6.2,1x,f7.3,1x,f5.1)'
  endelse

  ; select custom,common background region
  if (chip(i) eq 0 and offax_min(i) le 4) then $
    bkg="circle(3874.5,4202.5,81.09984)"
  if (chip(i) eq 0 and offax_min(i) gt 4) then $
    bkg="circle(3146.5,4642.5,114.70448)"
  if (chip(i) eq 1 and offax_min(i) le 4) then $
    bkg="circle(3914.5,3922.5,90.299886)"
  if (chip(i) eq 1 and offax_min(i) gt 4) then $
    bkg="circle(3378.5,3194.5,132.80559)"
  if (chip(i) eq 2 and offax_min(i) le 4) then $
    bkg="circle(4114.5,4346.5,71.244143)"
  if (chip(i) eq 2 and offax_min(i) gt 4) then $
    bkg="circle(4682.5,4858.5,131.46837)"
  if (chip(i) eq 3 and offax_min(i) le 4) then $
    bkg="circle(4274.5,4034.5,83.475185)"
  if (chip(i) eq 3 and offax_min(i) gt 4) then $
    bkg="circle(4938.5,3394.5,135.05951)"
  if (chip(i) eq 6) then $
    bkg="circle(6206.5,5018.5,80)"
  if (chip(i) eq 7) then $
    bkg="circle(5914.5,3402.5,80)"

  ; use my formula instead
  if (ellipse) then begin
    ang1=double(atan(double(y(i)-4096.5)/double(x(i)-4096.5)))*360.0/2.0/!pi
    ;if (ang1 lt 90.0) then ang1=ang1+90.0
    ;if (ang1 gt 270.0) then ang1=ang1-90.0
    p=95.4+0.47*ang1
    if (x(i) lt 4096.5) then p=p+90.0
;    p=(p+90.) mod 180.
    a=1.97-0.22*offax_min(i)+0.15*offax_min(i)^2
    b=2.03-0.13*offax_min(i)+0.08*offax_min(i)^2
    a=a/0.492  ; convert back to pixels
    b=b/0.492  ; convert back to pixels
    reg=strcompress("ellipse("+ $
                  string(x(i),format='(F8.3)')+","+ $
                  string(y(i),format='(F8.3)')+","+ $
                  string(a*1.5,format='(F7.3)')+","+ $
                  string(b*1.5,format='(F7.3)')+","+ $
                  string(p,format='(F6.2)')+")",/remove_all)
  endif ;if (ellipse) then begin



  printf, ounit, reg
  printf, bunit, bkg
endfor
free_lun, ounit
free_lun, bunit
free_lun, lunit



end
