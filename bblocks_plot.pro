PRO BBLOCKS_PLOT,infile,obsid

; make gifs of light curves w/ bayesian blocks
;  put in web area

number = long(obsid)
obsid = long(obsid)
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
  bbfile=strcompress(src_root+"/bblocks_plot.fits",/remove_all)
  fcnt=0
  ;found=findfile(strcompress(src_root+"/bblocks_plot.gif",/remove_all),count=fcnt)
  ;if (fcnt eq 0) then begin
  found=findfile(bbfile,count=fcnt)
  if (fcnt eq 1) then begin
    lc=mrdfits(bbfile,1)
    bb=mrdfits(bbfile,2)
    lc.y=lc.y*1000.
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
    outfile=strcompress(src_root+"/bblocks_plot.gif",/remove_all)
    write_gif,outfile,tvrd()

    psfile=strcompress(src_root+"/bblocks_plot.ps",/remove_all)
    set_plot,'ps'
    device,filename=psfile,/color,/encap
    plot,lc.x,lc.y,psym=10, $
      xrange=[0,xmax], yrange=[ymin,ymax],ystyle=1, xstyle=1, $
      ytitle="Rate (cpks)", xtitle="Time (sec)", $
      color=0, backg=255, $
      thick=1,chars=1.0,chart=1.0,xthick=1.0,ythick=1.0
    oplot,bb.x,bb.y, color=240, thick=2, psym=10
    device,/close
  endif else begin ; if (fcnt eq 1) then begin
    print, "Source ",src," bblocks not found.",bbfile
  endelse
  ;endif ; if (fcnt eq 0) then begin
  
endfor ; for i=0,n_elements(inlist)-1 do begin
;device,/close ;test
end 
