FUNCTION NO_AXIS_LABELS, axis, index, value
; suppress labelling axis
return, string(" ")
end

PRO mk_plot, file
xmin=0.3
xmax=8.0
dat=mrdfits(file,1)
fit=mrdfits(file,2)
res=mrdfits(file,3)
; res missing for unbinned data, calculate below
;  so program doesn't die
got_dat=1
got_fit=1
got_res=1
if (n_elements(dat) le 1) then got_dat=0
if (n_elements(fit) le 1) then got_fit=0
if (n_elements(res) le 1) then begin
  got_res=0
  if (got_dat and got_fit) then begin
    got_res=1
    b=where(dat.y gt 0,bnum)
    if (bnum ge 1) then begin  ; can't plot y <=0 on log scale
      dat=dat(b)
    endif ; if (bnum ge 1) then begin
    res=dat
    res.y=(dat.y-fit(b).y)/dat.yeup
    res.yeup=1
    res.yedn=1
  endif ;if (got_dat and got_fix) then begin
endif ; if (n_elements(res) le 1) then begin

ymin=min([dat.y,fit.y])
ymax=max([dat.y,fit.y])
ymax=2.0*ymax
ymin=0.5*ymin
;ymax=ymax+0.1*(ymax-ymin)
ymin=max([1e-6,ymin])
yup=dat.y+dat.yeup
ydn=dat.y-dat.yedn
b=where(ydn lt ymin,bnum)
if (bnum ge 1) then ydn(b)=ymin
resmin=(-2.0)
resmax= 2.0
print,"YYYY", ymin,ymax
print,"Ydat", min(dat.y),max(dat.y),n_elements(dat)
print,"Yfit", min(fit.y),max(fit.y)
print,"Yerr", min(dat.yedn),max(dat.yeup)
print,"Yerr0", dat(0).yedn,dat(0).yeup

out1=strsplit(file,"/",/extract)
out2=strsplit(out1(n_elements(out1)-1),".")
out3=strsplit(file,".",/extract)
outroot=out3(0)

;print,file
;print,outroot

!p.multi=[0,1,2,0,0]
set_plot, 'z'
device, set_resolution = [350,250]
if (got_dat) then begin
  plot,dat.x,dat.y,psym=2, symsize=0.2, $
    xrange=[xmin,xmax], yrange=[ymin,ymax],ystyle=1, xstyle=1, $
    ytitle="counts/sec/keV", xtitle="", xtickformat='no_axis_labels', $
    color=0, backg=255, /xlog,/ylog, ymargin=[-4,3], $
    thick=1,chars=0.8,chart=1.0,xthick=1.0,ythick=1.0, $
    xtickv=[0.5,0.6,0.8,1.0,2,3,4,5,6,7,8],xticks=10, $
    xtickn=['0.5'," "," ",'1','2'," "," ",'5'," "," ",'8']
  if (got_fit) then oplot,fit.x,fit.y,color=240,thick=2,psym=10
  ;  ploterr,errplot.oploterr do not work well for gifs, do by hand
  !P.COLOR=0
  if (n_elements(tag_names(dat)) eq 4) then begin
    ;errplot,dat.x,ydn,yup
    for idat=0,n_elements(dat)-1 do begin
      oplot,[dat(idat).x,dat(idat).x], [ydn(idat),yup(idat)], $
            linestyle=0,thick=1
    endfor
  endif

  if (got_res) then begin
    plot,res.x,res.y,psym=2, symsize=0.2, $
      xrange=[xmin,xmax], yrange=[resmin,resmax],ystyle=1, xstyle=1, $
      ytitle="Sigma", xtitle="Energy (keV)", $
      color=0, backg=255, /xlog, ymargin=[4,4], $
      thick=1,chars=0.8,chart=1.0,xthick=1.0,ythick=1.0, $
      xtickv=[0.5,0.6,0.8,1.0,2,3,4,5,6,7,8],xticks=10, $
      xtickn=['0.5'," "," ",'1','2'," "," ",'5'," "," ",'8'], $
      yticks=2
    !P.COLOR=0
    if (n_elements(tag_names(res)) eq 4) then begin
      errplot,res.x,res.y-res.yedn,res.y+res.yeup
    endif
    ;for ierr=0,n_elements(res.x)-1 do begin
    ;  oplot,[res.x,res.x],[res.y,res.y-res.yedn],thick=1
    ;  oplot,[res.x,res.x],[res.y,res.y+res.yeup],thick=1
    ;endfor
    oplot,[xmin,xmax],[0,0]
  endif ; if (got_res) then begin
endif ; if (got_dat) then begin
outfile=strcompress(outroot+".gif",/remove_all)
write_gif,outfile,tvrd()

!p.multi=[0,1,2,0,0]
psfile=strcompress(outroot+".ps",/remove_all)
set_plot,'ps'
device,filename=psfile,/color,/encap,xsize=4,ysize=4,/inches
if (got_dat) then begin
  plot,dat.x,dat.y,psym=2, symsize=0.2, $
    xrange=[xmin,xmax], yrange=[ymin,ymax],ystyle=1, xstyle=1, $
    ytitle="counts/sec/keV", xtitle="", xtickformat='no_axis_labels', $
    color=0, backg=255, /xlog,/ylog, ymargin=[-4,3], $
    thick=1,chars=1.0,chart=2.0,xthick=2.0,ythick=2.0, $
    xtickv=[0.5,0.6,0.8,1.0,2,3,4,5,6,7,8],xticks=10, $
    xtickn=['0.5'," "," ",'1','2'," "," ",'5'," "," ",'8']
  if (got_fit) then oplot,fit.x,fit.y,color=240,thick=2,psym=10
  !P.COLOR=0
  if (n_elements(tag_names(dat)) eq 4) then begin
    ;errplot,dat.x,ydn,yup
    for idat=0,n_elements(dat)-1 do begin
      oplot,[dat(idat).x,dat(idat).x], [ydn(idat),yup(idat)], $
            linestyle=0,thick=1
    endfor
  endif

  if (got_res) then begin
    plot,res.x,res.y,psym=2, symsize=0.2, $
      xrange=[xmin,xmax], yrange=[resmin,resmax],ystyle=1, xstyle=1, $
      ytitle="Sigma", xtitle="Energy (keV)", $
      color=0, backg=255, /xlog, ymargin=[4,4], $
      thick=1,chars=1.0,chart=2.0,xthick=2.0,ythick=2.0, $
      xtickv=[0.5,0.6,0.8,1.0,2,3,4,5,6,7,8],xticks=10, $
      xtickn=['0.5'," "," ",'1','2'," "," ",'5'," "," ",'8'], $
      yticks=2
    !P.COLOR=0
    if (n_elements(tag_names(res)) eq 4) then begin
      errplot,res.x,res.y-res.yedn,res.y+res.yeup
    endif
    oplot,[xmin,xmax],[0,0]
  endif ; if (got_res)
endif ; if (got_dat)
device,/close
end 

PRO SPECTRA_PLOT,infile,obsid

; make ps and gifs of spectra
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
for i=0,n_elements(inlist)-1 do begin
  tmp=strsplit(inlist(i)," ",/extract)
  tmp2=strsplit(tmp(0),"_",/extract)
  src=strcompress(string(tmp2(1)),/remove_all)
  src_root=strcompress(data_root+"/src"+src,/remove_all)
  spcstat=0
  sprun=findfile(strcompress(src_root+"/cstat.fits",/remove_all),count=spcstat)
  spcnt=0
  if (spcstat ge 1) then begin
    sprun=[sprun,findfile(strcompress(src_root+"/c_rs*.fits",/remove_all),count=spcnt)]
  endif else begin
    sprun=findfile(strcompress(src_root+"/c_rs*.fits",/remove_all),count=spcnt)
  endelse
  print,"nfiles ",spcstat+spcnt
  for j=0,spcnt+spcstat-1 do begin
    out1=strsplit(sprun(j),"/",/extract)
    out2=strsplit(out1(n_elements(out1)-1),".",/extract)
    ;out3=strsplit(out2,".",/extract)
    outroot=out2(0)
    spran=findfile(strcompress(outroot+".gif",/remove_all),count=ngifs)
    ;if (ngifs eq 0) then mk_plot,sprun(j)
    print,sprun(j)
    mk_plot,sprun(j)
  endfor ; for j=0,spcnt-1 do begin
endfor ; for i=0,n_elements(inlist)-1 do begin
end 
