PRO GLvary_PLOT  ,infile,obsid

; make gifs of light curves w/ GLvary code
;  put in web area

number = long(obsid)
obsid  = long(obsid)
obsid  = strcompress(string(obsid), /remove_all)
if (number lt 10) then obsidf = '0000'+obsid
if (number ge 10) and (number lt 100) then obsidf = '000'+obsid
if (number ge 100) and (number lt 1000) then obsidf = '00'+obsid
if (number ge 1000) and (number lt 10000) then obsidf = '0'+obsid
if (number ge 10000) then obsidf = obsid
data_root=strcompress("/data/ANCHORS/YAXX/"+obsidf+"/Data/obs"+obsid,/remove_all)

readcol,infile,inlist,x,ra,dec,format='a,f,f,f',skipline=2

loadct,39
!p.multi=[0,1,1,0,0]
for i=0,n_elements(inlist)-1 do begin
  tmp=strsplit(inlist(i)," ",/extract)
  tmp2=strsplit(tmp(0),"_",/extract)
  src=strcompress(string(tmp2(1)),/remove_all)
  src_root=strcompress(data_root+"/src"+src,/remove_all)
  bbfile=strcompress(src_root+"/bblocks_plot.fits",/remove_all)    ; modify file name for diff. significance levels
  ; ---obtain GLvary results through the following steps:
  ; to remove all the text above the lightcurve table, do the following unix awk command:
;  spawn,  "awk '$1 > 10000000 {print $1, $2, $3, $4, $5}' "+ $
;          src_root + "/GLvary.out > " + src_root + "/GLvary_LC.out"

  glvaryfile=strcompress(src_root+"/GLvary_LC.out",/remove_all)
  readcol, glvaryfile, time, Flux, sigma, m3sigma, p3sigma, format='f, f, f, f, f'
           tstart=215060705.165316   ; starting time of the observation
           time=time-tstart
           time_value=time  
           flux = flux*1000.

;             time_value=fltarr(n_elements(time)-1)            ;-----------------------------------------;
;             nmax=n_elements(time)-2                          ; This section is for selection of        ;
;             for k=0, nmax do begin                           ; the GLvary flux measurements to be      ;
;              time_value[k] = (time[k] + time[k+1]) / 2.      ; centered between time[k] and time[k+1]  ;
;             endfor                                           ; (middle of the "bin" in positive dir.)  ;
;             flux = flux[0:nmax]                              ;-----------------------------------------;
 
;             time_value=fltarr(n_elements(time)-1)            ;-----------------------------------------;
;             nmax=n_elements(time)-2                          ; This section is for selection of the    ;
;             for K=0, nmax do begin                           ; GLvary flux measurements to be centered ;
;              time_value[k] = time[k+1]                       ; on the beginning of the next time value.; 
;             endfor                                           ;-----------------------------------------;
 
  fcnt=0
  ;found=findfile(strcompress(src_root+"/bblocks_plot.gif",/remove_all),count=fcnt)
  ;if (fcnt eq 0) then begin
  found=findfile(bbfile,count=fcnt)
  if (fcnt eq 1) then begin
    lc=mrdfits(bbfile,1)
    bb=mrdfits(bbfile,2)
    lc.y=lc.y*1000.   ; lightcurve 
    bb.y=bb.y*1000.
    ymin=min(lc.y)
    ymax=max(lc.y)
    ymin=ymin-0.1*(ymax-ymin)
    ymax=ymax+0.1*(ymax-ymin)
    xmax=max(lc.x)
    set_plot, 'z'
    device, set_resolution = [350,250]
    plot,lc.x,lc.y,psym=10, $
      xrange=[0,xmax], yrange=[ymin,ymax],ystyle=1, xstyle=1, $
      ytitle="Rate (cpks)", xtitle="Time (sec)", $
      color=0, backg=255, $
      thick=1,chars=0.8,chart=1.0,xthick=1.0,ythick=1.0
  
    for j=2, n_elements(bb)-2,2 do begin  
      if (bb(j+1).x-bb(j).x lt 500) then begin
        bb(j).y=bb(j-1).y
        bb(j+1).y=bb(j-1).y
    endif ; if (bb(j+1).x-bb(j).x lt 500) then begin
    endfor ; for j=1, n_elements(bb)-2,2 do begin
    oplot,bb.x,bb.y, color=240, thick=2, psym=10
;    outfile=strcompress(src_root+"/bblocks_plot.gif",/remove_all)
;    write_gif,outfile,tvrd()

    psfile=strcompress(src_root+"/bblocks_glvary_plot.ps",/remove_all)
    set_plot,'ps'
    device,filename=psfile,/color,/encap
    plot,lc.x,lc.y,psym=10, $
      xrange=[0,xmax], yrange=[ymin,ymax],ystyle=1, xstyle=1, $
      ytitle="Rate (cpks)", xtitle="Time (sec)", $
      color=0, backg=255, $
      thick=1,chars=1.0,chart=1.0,xthick=1.0,ythick=1.0
    oplot,bb.x,bb.y, color=240, thick=2, psym=10
    oplot, time_value, flux, psym=10, color=100
    ;xyouts, xmax - 0.25*xmax, ymax - 0.05*ymax, "BBlocks run at !C99.9% confidence level", charsize=0.8
    xyouts, xmax - 0.95*xmax, ymax - 0.05*ymax, "GLvary flux is centered !C at bin!LN", charsize=0.8
                                                ;"GLvary flux is centered between !C bin!LN!N and bin!LN+1", charsize=0.8 
                                                ;"GLvary flux is centered !Cat bin N+1", charsize=0.8
    device,/close
  endif else begin ; if (fcnt eq 1) then begin
    print, "Source ",src," bblocks not found."
  endelse
  ;endif ; if (fcnt eq 0) then begin
  
endfor ; for i=0,n_elements(inlist)-1 do begin
;device,/close ;test
end 
