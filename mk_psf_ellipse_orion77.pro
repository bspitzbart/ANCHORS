PRO MK_PSF_ELLIPSE_ORION77,obsid, obs_roll
; we are using a subset of all sources, but need to include all sources in backgrounds

; mk psf regions and exclude file for swiss cheese backgrounds.

readcol,'calc_theta_phi.out',src,x,y,offax_min,ang,ra,dec,chip, $
        format='f,f,f,f,f,f,f,f'

rdfloat,'/data/ANCHORS/YAXX/Data/fit_ellipse.dat', $
        ell_theta,ell_phi,ell_energy,ell_x,ell_y,ell_a,ell_b,ell_p, $
        skipline=1

ell=mrdfits('/data/ANCHORS/YAXX/Data/hrmaD1996-12-20hrci_ell_ecf_N0003.fits.gz',1)
cir=mrdfits('/data/ANCHORS/YAXX/Data/hrmaD1996-12-20hrci_ecf_N0002.fits.gz',1)
iecf=where(ell(0).ecf eq 0.95)
ienergy=where(ell(0).energy eq 1.0)

openw, ounit, 'src_psf_ell_old.reg', /get_lun
openw, eunit, 'src_psf_exc_old.reg', /get_lun
openw, bunit, 'bkg_psf_ell_old.reg', /get_lun
openw, cal_ounit, 'src_psf_ell_cal.reg', /get_lun
openw, cal_eunit, 'src_psf_exc_cal.reg', /get_lun
openw, cal_bunit, 'bkg_psf_ell_cal.reg', /get_lun
;openw, yaxx_ounit, 'src_yaxx.reg', /get_lun
;openw, yaxx_bunit, 'bkg_yaxx.reg', /get_lun
openw, yaxx_ounit, 'src_psf_ell.reg', /get_lun
openw, yaxx_bunit, 'bkg_psf_ell.reg', /get_lun
openw, lunit, 'mk_psf_ell_reg.log', /get_lun

a_tot=fltarr(n_elements(x))
b_tot=fltarr(n_elements(x))
p_tot=fltarr(n_elements(x))
x_tot=fltarr(n_elements(x))
y_tot=fltarr(n_elements(x))

; estimate CCD outline
;debug print,min(x),max(x),min(y),max(y)
bxmin=where(x eq min(x))
bxmax=where(x eq max(x))
bymin=where(y eq min(y))
bymax=where(y eq max(y))
;debug print,bxmin,bxmax,bymin,bymax
;debug print,x(bxmin(0)),x(bxmax(0)),y(bymin(0)),y(bymax(0))
box=strcompress("polygon("+ $
               string(x(bxmin(0))-20)+","+string(y(bxmin(0)))+","+ $
               string(x(bymin(0)))+","+string(y(bymin(0))-20)+","+ $
               string(x(bxmax(0))+20)+","+string(y(bxmax(0)))+","+ $
               string(x(bymax(0)))+","+string(y(bymax(0))+20)+")", $
               /remove_all)
;debug print,box

for i=0,n_elements(x)-1 do begin

  ; calculate azimuthal angle
  ; select circles or ellipses based on offax_min
  if (offax_min(i) ge 0) then begin
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
    ;print,x(i),y(i),y_lo,y_hi,y_off,z_lo,z_hi,z_off
    x(i)=x(i)+(z_off*60./0.492)
    y(i)=y(i)+(y_off*60./0.492)
    ;print,x(i),y(i)
    p_tot(i)=(((ang(i)-phi_lo)*(p_hi-p_lo))/(phi_hi-phi_lo))+p_lo
    a_tot(i)=a/0.492  ; convert back to pixels
    b_tot(i)=b/0.492  ; convert back to pixels
    printf, lunit,x(i),y(i),p_tot(i),offax_min(i),ang(i), $
                    mat(0).theta(itheta(0)),mat(0).phi(iphi(0))

    ; recalculate p with new matrix
    dell_theta=abs(offax_min(i)-ell_theta)
    dell_phi=abs(ang(i)-ell_phi)
    iell=where(dell_theta eq min(dell_theta) and  $
               dell_phi eq min(dell_phi) and ell_energy eq 2,iell_num)
    if (iell_num eq 1) then begin
      p_tot(i)=(ell_p(iell) + obs_roll) mod 180
    endif else begin
      print, "no ellipse rotation estimate found for source ", i
    endelse

    ; ignore all above and use RCW38 formula
    ;p_tot(i)=(ang(i)*0.47+45.2+obs_roll) mod 180
    p_tot(i)=(ang(i)*0.47+146.6-obs_roll+360) mod 180

  endif ; else begin
  ; let's not use circles for test
  ;   all recalcs, recenter, and bkg calcs have to be added
  ;  r=(((ang(i)-phi_lo)*(r_hi-r_lo))/(phi_hi-phi_lo))+r_lo
  ;  r=r*2.0/0.492
  ;  reg=strcompress("circle("+ $
  ;                  string(x(i),format='(F8.3)')+","+ $
  ;                  string(y(i),format='(F8.3)')+","+ $
  ;                  string(r,format='(F7.3)')+")",/remove_all)
  ;  exc=strcompress("circle("+ $
  ;                  string(x(i),format='(F8.3)')+","+ $
  ;                  string(y(i),format='(F8.3)')+","+ $
  ;                  string(r*3.0,format='(F7.3)')+")",/remove_all)
  ;  bkg=strcompress("circle("+ $
  ;                  string(x(i),format='(F8.3)')+","+ $
  ;                  string(y(i),format='(F8.3)')+","+ $
  ;                  string(r*6.0,format='(F7.3)')+")",/remove_all)
  ;  printf, lunit,x(i),y(i),r,offax_min(i),ang(i), $
  ;                  mat(0).theta(itheta(0)),mat(0).phi(iphi(0))
  ;endelse
endfor
; recentroid
x_tot=x
y_tot=y
;debug print,obsid
psf_centroid,obsid,x,y,b_tot,x_tot,y_tot
;ang_org=p_tot
;psf_fit_ell,obsid,x,y,a_tot,b_tot,xf=x_tot,yf=y_tot,ang=p_tot

for i=0,n_elements(x)-1 do begin
    reg=strcompress("ellipse("+ $
                    string(x_tot(i),format='(F8.3)')+","+ $
                    string(y_tot(i),format='(F8.3)')+","+ $
                    string(a_tot(i),format='(F7.3)')+","+ $
                    string(b_tot(i),format='(F7.3)')+","+ $
                    string(p_tot(i),format='(F7.2)')+")",/remove_all)
    exc=strcompress("ellipse("+ $
                    string(x_tot(i),format='(F8.3)')+","+ $
                    string(y_tot(i),format='(F8.3)')+","+ $
                    string(a_tot(i)*3.0,format='(F7.3)')+","+ $
                    string(b_tot(i)*3.0,format='(F7.3)')+","+ $
                    string(p_tot(i),format='(F7.2)')+")",/remove_all)
    bkg=strcompress("ellipse("+ $
                    string(x_tot(i),format='(F8.3)')+","+ $
                    string(y_tot(i),format='(F8.3)')+","+ $
                    string(a_tot(i)*6.0,format='(F7.3)')+","+ $
                    string(b_tot(i)*6.0,format='(F7.3)')+","+ $
                    string(p_tot(i),format='(F7.2)')+")",/remove_all)
  printf, cal_ounit, reg
  printf, cal_eunit, exc
  printf, cal_bunit, bkg
  printf, yaxx_ounit, reg

  bkg=bkg+"-"+exc ; start building yaxx bkg region
  diff=sqrt((x-x(i))^2+(y-y(i))^2)
  a_dist=6.0*(a_tot(i)+a_tot)  ; calculate max distance to all other sources
  bdiff=where(diff le a_dist,bdiffnum)
  print, "src",src(i)," ",bdiffnum," neighbors"
  if (bdiffnum ge 1) then begin
    for idiffnum=0,bdiffnum-1 do begin
      idiff=bdiff(idiffnum)
      exc=strcompress("ellipse("+ $
                      string(x_tot(idiff),format='(F8.3)')+","+ $
                      string(y_tot(idiff),format='(F8.3)')+","+ $
                      string(a_tot(idiff)*3.0,format='(F7.3)')+","+ $
                      string(b_tot(idiff)*3.0,format='(F7.3)')+","+ $
                      string(p_tot(idiff),format='(F7.2)')+")",/remove_all)
      bkg=bkg+"-"+exc
    endfor ; for idiffnum=0,bdiffnum-1 do begin
    printf, yaxx_bunit, bkg
  endif ; if (bdiffnum ge 1) then begin

endfor
free_lun, ounit
free_lun, eunit
free_lun, bunit
free_lun, lunit
free_lun, cal_ounit
free_lun, cal_eunit
free_lun, cal_bunit
free_lun, yaxx_ounit
free_lun, yaxx_bunit
end
