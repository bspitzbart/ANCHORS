PRO PSF_CENTROID, obsidt, xi, yi, ma, xf, yf

;========================================================================;
; This routine cuts out an annulus around each x-ray source on event2    ;
; image using provided coordinates and radius/minor axis of that         ;
; source's 90% encircled energy region.                                  ;
; It then finds a centeral location of the source by calculating         ;
; the centroid based on the PSF brightness distribution.                 ;
; Currently, the PSF is assumed to be of simple elliptical of circular   ; 
; shape.                                                                 ;
;------------------------------------------------------------------------; 
; xi,yi = initial physical coodrinates of each source                    ;
; ma = minor axis or radius or each source's elliptical/circular region  ;
; xf,yf = corrected physical coordinates of each source after centroiding;
;========================================================================;

;  input event file must be named as follows: evt2_0.5-7.5_f.fits
;  the kind used is filtered by energy from 0.3 to 8keV



obsid  = strcompress(string(obsidt), /remove_all)
     number = long(obsid)
     if (number lt 10) then obsidf = '0000'+obsid
     if (number ge 10) and (number lt 100) then obsidf = '000'+obsid
     if (number ge 100) and (number lt 1000) then obsidf = '00'+obsid
     if (number ge 1000) and (number lt 10000) then obsidf = '0'+obsid
     if (number ge 10000) then obsidf = obsid 

eventfile='/data/mta4/AExtract/YAXX/'+obsidf+'/Data/obs'+obsid+'/evt2_0.5-7.5_f.fits'
eventfile=STRCOMPRESS(eventfile, /remove_all)
aperture= '/data/mta4/AExtract/YAXX/'+obsidf+'/Data/obs'+obsid+'/ApertureImages/aperture'
aperture=STRCOMPRESS(aperture, /remove_all)

regionsarray=strarr(1,n_elements(xi))

for i=0, n_elements(xi)-1 do begin
index=i+1
index=STRCOMPRESS(index, /remove_all)

regionsarray = 'circle('+STRCOMPRESS(xi, /remove_all)+','+STRCOMPRESS(yi, /remove_all)+','+STRCOMPRESS(ma, /remove_all)+')'

regionsarray=STRCOMPRESS(regionsarray[i], /remove_all)

xmin=fix(xi[i]-100., type=4)
 xmin=STRCOMPRESS(xmin, /remove_all)
xmax=fix(xi[i]+100., type=4)
 xmax=STRCOMPRESS(xmax, /remove_all)
ymin=fix(yi[i]-100., type=4)
 ymin=STRCOMPRESS(ymin, /remove_all)
ymax=fix(yi[i]+100., type=4)
 ymax=STRCOMPRESS(ymax, /remove_all)

quote='"'
spawn, '/soft/ciao/bin/dmcopy ' + quote + eventfile + '[sky=' + regionsarray + '][bin x=' +$
       xmin + ':' + xmax + ':1,y=' + ymin + ':' + ymax + ':1]'+quote+$
       aperture + index + '.fits clobber=yes mode=h'

endfor

 xf=fltarr(n_elements(xi))
 yf=fltarr(n_elements(xi)) 
 xxbar=fltarr(n_elements(xi))
 yybar=fltarr(n_elements(xi))
 for i=0, n_elements(xi)-1 do begin
  index=i+1
  index=STRCOMPRESS(index, /remove_all)
  array=mrdfits(aperture+index+'.fits')

  skyback=0.1
  xbar=0
  ybar=0
  counts=0
  if (ma[i] ge 100) then ma[i]=99
  CENTROD, array, 100,100, ma[i], ma[i]+5., ma[i]+15., skyback, xbar, ybar, counts
  xf[i]=xi[i]+(xbar-100.)
  yf[i]=yi[i]+(ybar-100.)
  xxbar[i]=xbar
  yybar[i]=ybar
 endfor


end
