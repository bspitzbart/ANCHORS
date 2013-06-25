PRO MK_PSF_ELLIPSE_EXC

; mk psf regions and exclude file for swiss cheese backgrounds.

readcol,'calc_theta_phi.out',src,x,y,offax_min,ang,ra,dec,chip, $
        format='f,f,f,f,f,f,f,f'

ell=mrdfits('/data/mta4/AExtract/YAXX/Data/hrmaD1996-12-20hrci_ell_ecf_N0003.fits.gz',1)
cir=mrdfits('/data/mta4/AExtract/YAXX/Data/hrmaD1996-12-20hrci_ecf_N0002.fits.gz',1)
iecf=where(ell(0).ecf eq 0.95)
ienergy=where(ell(0).energy eq 1.0)

openw, ounit, 'src_psf_ell.reg', /get_lun
openw, eunit, 'src_psf_exc.reg', /get_lun
openw, bunit, 'bkg_psf_ell.reg', /get_lun
openw, cal_ounit, 'src_psf_ell_cal.reg', /get_lun
openw, cal_eunit, 'src_psf_exc_cal.reg', /get_lun
openw, cal_bunit, 'bkg_psf_ell_cal.reg', /get_lun
openw, lunit, 'mk_psf_ell_reg.log', /get_lun

for i=0,n_elements(x)-1 do begin

  ; calculate azimuthal angle
  ; select circles or ellipses based on offax_min
  if (offax_min(i) gt 0) then begin
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
    y_lo=mat(0).y(iecf(0),itheta(0),iphi(0),ienergy(0))
    z_lo=mat(0).z(iecf(0),itheta(0),iphi(0),ienergy(0))
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
    y_hi=mat(0).y(iecf(0),itheta(0),iphi(0),ienergy(0))
    z_hi=mat(0).z(iecf(0),itheta(0),iphi(0),ienergy(0))
    p_hi=(mat(0).pa(iecf(0),itheta(0),iphi(0),ienergy(0))+180.) mod 180
  endif else begin
    r_hi=mat(0).radius(iecf(0),itheta(0),iphi(0),ienergy(0))
  endelse

  ; interpolate by phi
  if (ellipse) then begin
    a=(((ang(i)-phi_lo)*(a_hi-a_lo))/(phi_hi-phi_lo))+a_lo
    b=(((ang(i)-phi_lo)*(b_hi-b_lo))/(phi_hi-phi_lo))+b_lo
    y_off=(((ang(i)-phi_lo)*(y_hi-y_lo))/(phi_hi-phi_lo))+y_lo
    z_off=(((ang(i)-phi_lo)*(z_hi-z_lo))/(phi_hi-phi_lo))+z_lo
    p=(((ang(i)-phi_lo)*(p_hi-p_lo))/(phi_hi-phi_lo))+p_lo
    ;print,x(i),y(i),y_lo,y_hi,y_off,z_lo,z_hi,z_off
    x(i)=x(i)+(z_off*60./0.492)
    y(i)=y(i)+(y_off*60./0.492)
    ;print,x(i),y(i)
    a=a/0.492  ; convert back to pixels
    b=b/0.492  ; convert back to pixels
    reg=strcompress("ellipse("+ $
                    string(x(i),format='(F8.3)')+","+ $
                    string(y(i),format='(F8.3)')+","+ $
                    string(a,format='(F7.3)')+","+ $
                    string(b,format='(F7.3)')+","+ $
                    string(p,format='(F6.2)')+")",/remove_all)
    exc=strcompress("ellipse("+ $
                    string(x(i),format='(F8.3)')+","+ $
                    string(y(i),format='(F8.3)')+","+ $
                    string(a*3.0,format='(F7.3)')+","+ $
                    string(b*3.0,format='(F7.3)')+","+ $
                    string(p,format='(F6.2)')+")",/remove_all)
    bkg=strcompress("ellipse("+ $
                    string(x(i),format='(F8.3)')+","+ $
                    string(y(i),format='(F8.3)')+","+ $
                    string(a*6.0,format='(F7.3)')+","+ $
                    string(b*6.0,format='(F7.3)')+","+ $
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
    exc=strcompress("circle("+ $
                    string(x(i),format='(F8.3)')+","+ $
                    string(y(i),format='(F8.3)')+","+ $
                    string(r*3.0,format='(F7.3)')+")",/remove_all)
    bkg=strcompress("circle("+ $
                    string(x(i),format='(F8.3)')+","+ $
                    string(y(i),format='(F8.3)')+","+ $
                    string(r*6.0,format='(F7.3)')+")",/remove_all)
    printf, lunit,x(i),y(i),r,offax_min(i),ang(i), $
                    mat(0).theta(itheta(0)),mat(0).phi(iphi(0))
  endelse
  printf, cal_ounit, reg
  printf, cal_eunit, exc
  printf, cal_bunit, bkg

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
    exc=strcompress("ellipse("+ $
                  string(x(i),format='(F8.3)')+","+ $
                  string(y(i),format='(F8.3)')+","+ $
                  string(a*3.0,format='(F7.3)')+","+ $
                  string(b*3.0,format='(F7.3)')+","+ $
                  string(p,format='(F6.2)')+")",/remove_all)
    bkg=strcompress("ellipse("+ $
                  string(x(i),format='(F8.3)')+","+ $
                  string(y(i),format='(F8.3)')+","+ $
                  string(a*6.0,format='(F7.3)')+","+ $
                  string(b*6.0,format='(F7.3)')+","+ $
                  string(p,format='(F6.2)')+")",/remove_all)
  endif ;if (ellipse) then begin

  printf, ounit, reg
  printf, eunit, exc
  printf, bunit, bkg
endfor
free_lun, ounit
free_lun, eunit
free_lun, bunit
free_lun, lunit
free_lun, cal_ounit
free_lun, cal_eunit
free_lun, cal_bunit
end
