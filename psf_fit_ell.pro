PRO PSF_FIT_ELL, obsidt,x,y,majr,minr,xf=XF,yf=YF,ang=ANG

; recenter and fit the ellipse angle around a region of interest.
; given obsid (do find evtfile), and original,x,y (in sky coords),
;  major axis, and minor axis, calculate and return
;  recentered x,y and fitted ang in named variables
; derived from Teague, "Image Analysis via the General theory of Moments",
;    J. Opt. Soc. Am. 70, 1980.

;  input event file must be named as follows: evt2_efilt.fits

openw,LOG,"psf_fit_ell.log",/get_lun

obsid  = strcompress(string(obsidt), /remove_all)
     number = long(obsid)
     if (number lt 10) then obsidf = '0000'+obsid
     if (number ge 10) and (number lt 100) then obsidf = '000'+obsid
     if (number ge 100) and (number lt 1000) then obsidf = '00'+obsid
     if (number ge 1000) and (number lt 10000) then obsidf = '0'+obsid
     if (number ge 10000) then obsidf = obsid 

eventfile='/data/ANCHORS/YAXX/'+obsidf+'/Data/obs'+obsid+'/evt2_efilt.fits'
evtfile=STRCOMPRESS(eventfile, /remove_all)
evt=mrdfits(evtfile,1)

for i=0,n_elements(x)-1 do begin
  
  ; build image
  xsize=ceil(majr(i))
  ysize=xsize
  print,"building image frame ",xsize*2," X ",ysize*2 ; debug
  xmin=x(i)-xsize+1
  xmax=x(i)+xsize
  ymin=y(i)-ysize+1
  ymax=y(i)+ysize
  img=hist_2d(evt.x,evt.y,min1=xmin,max1=xmax,min2=ymin,max2=ymax)
  ; make smaller image for recentering
  xsize_sm=ceil(minr(i))
  ysize_sm=xsize_sm
  xmin_sm=xsize-xsize_sm+1
  xmax_sm=xsize+xsize_sm
  ymin_sm=ysize-ysize_sm+1
  ymax_sm=ysize+ysize_sm
  img_sm=img
  ;print,majr(i),minr(i),xsize,xsize_sm ;debug
  ;print,n_elements(img_sm),xmin_sm,xmax_sm,xmin,xmax ;debug
  img_sm(0:xmin_sm,*)=0
  img_sm(xmax_sm:majr(i)*2,*)=0
  img_sm(*,0:ymin_sm)=0
  img_sm(*,ymax_sm:majr(i)*2)=0
  
  ; recenter centrod
  skyback=0.1
  xcm=0
  ycm=0
  counts=0
  CENTROD, img_sm, minr(i),minr(i), minr[i], minr[i]+5., minr[i]+15., $
          skyback, xcm, ycm, counts
  
  ; use moment method for angle
  m_1_1=0
  m_2_0=0
  m_0_2=0
  for xr=0,majr(i)*2 do begin
    for yr=0,majr(i)*2 do begin
      m_1_1=m_1_1+(img(xr,yr)*xr*yr)
      m_2_0=m_2_0+(img(xr,yr)*xr^2*yr^0)
      m_0_2=m_0_2+(img(xr,yr)*xr^0*yr^2)
    endfor
  endfor
  ang(i)=(0.5*atan(2*m_1_1/(m_2_0-m_0_2))*180./!pi)+90.0
  printf,LOG,"Centroid/moment x_off, y_off, ang ",xcm-minr(i),ycm-minr(i),ang(i)
  xf(i)=x(i)+(xcm-minr(i))
  yf(i)=y(i)+(ycm-minr(i))

  ; the following is derived for comparison from 
  ;       http://www.dfanning.com/ip_tips/fit_ellipse.html
  ; calculate the center of mass of the ROI
  ;print,"Calculating center of mass" ; debug
  totalMass = Total(img_sm)
  xcm = Total( Total(img_sm, 2) * Indgen(xsize) ) / totalMass
  ycm = Total( Total(img_sm, 1) * Indgen(ysize) ) / totalMass

  ;xcm=majr(i) ;debug
  ;ycm=majr(i) ;debug
  
  ; locate each ROI pixel in the array with respect to the center of mass
  xcen = Findgen(xsize)
  ycen = Findgen(ysize)
  xx = (xcen # (ycen * 0 + 1)) - xcm
  yy = ((xcen * 0 + 1) # ycen) - ycm

  ; calculate the mass distribution tensor for these pixels.
  indices=indgen(n_elements(img))
  npts = N_Elements(indices)
  i11 = Total(yy[indices]^2) / npts
  i22 = Total(xx[indices]^2) / npts
  i12 = -Total(xx[indices] * yy[indices]) / npts
  tensor = [ [i11, i12], [i12,i22] ]

  ; use the tensor to calculate the eigenvalues and eigenvectors
  evals = Eigenql(tensor, Eigenvectors=evecs)

  ; The orientation is calculated in degrees counter-clockwise from the X axis
  evec = evecs[*,0]
  orientation = ATAN(evec[1], evec[0]) * 180. / !Pi - 90.0

  printf,LOG,"Eigengl  method x_off, y_off, ang ",xcm-majr(i),ycm-majr(i),orientation

endfor ;for i=0,n_elements(x)-1 do begin

free_lun,LOG

end

