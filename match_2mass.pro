pro match_2mass
 
readcol,'../04503/Data/obs4503/fp_2mass23637.tbl',ra,dec,j_m,j_err,h_m,h_err,k_m,k_err,ph_qual, $
  rd_flg,bl_flg,cc_flg,gal_contam,mp_flg, $
  format='f,f,f,f,f,f,f,f,a,a,a,a,a,a', skipline=15
rdfloat,'../04503/Data/obs4503/sources_ra_dec.txt',bnum,num,bra,bdec,skipline=4

bra_hr=bra/360.0*24.0
ra_hr=ra/360.0*24.0
match=lonarr(n_elements(bra))
mdiff=fltarr(n_elements(bra))
gcirc,1,bra_hr,bdec,249.99454304232/360.0*24.0,-48.865044769556,offax
for i=0,n_elements(bra)-1 do begin
  print,i
  gcirc,1,bra_hr(i),bdec(i),ra_hr,dec,diff
  ;diff=sphdist(bra(i),bdec(i),ra,dec,/degrees)
  ;diff=diff*3600.
  ;diff=sqrt((bra(i)-ra)^2+(bdec(i)-dec)^2)
  mdiff(i)=min(diff,m)
  match(i)=m
  ;if (mdiff(0) lt 0.0014) then begin
  ;  match(i)=m
  ;endif else begin
  ;  match(i)=n_elements(ra)
  ;endelse
endfor

ra =[ra,0]
dec =[dec,0]
j_m =[j_m,0]
j_err =[j_err,0]
h_m =[h_m,0]
h_err =[h_err,0]
k_m =[k_m,0]
k_err =[k_err,0]
ph_qual =[ph_qual,"XXX"]
rd_flg =[rd_flg,"XXX"]
bl_flg =[bl_flg,"XXX"]
cc_flg =[cc_flg,"XXX"]
gal_contam =[gal_contam,"XXX"]
mp_flg =[mp_flg,"XXX"]

print,n_elements(where(bl_flg(match) eq '222'))
;           1
print,n_elements(where(bl_flg(match) eq '111'))
;         241
print,n_elements(where(ph_qual(match) eq 'AAA'))
;         135
print,n_elements(where(ph_qual  eq 'AAA'))
;       44005
print,n_elements(where(bl_flg eq '111'))
;       79522
print,n_elements(where(bl_flg eq '222'))
;        1222
 
openw,OUT,'match_2mass.out',/get_lun
printf,OUT,"xr_ra xr_dec xr_offax ir_ra ir_dec offset j_m j_err h_m h_err k_m k_err ph_qual rd_flg bl_flg cc_flg gal_contam mp_flg"
for i=0,n_elements(match)-1 do begin
  printf,OUT,bra(i),bdec(i),offax(i),ra(match(i)),dec(match(i)), $
             mdiff(i), $
             j_m(match(i)),j_err(match(i)), $
             h_m(match(i)),h_err(match(i)), $
             k_m(match(i)),k_err(match(i)), $
             ph_qual(match(i)),rd_flg(match(i)), $
             bl_flg(match(i)),cc_flg(match(i)), $
             gal_contam(match(i)),mp_flg(match(i)), $
             format='(F9.5," ",F9.5," ",F9.5," ",F9.5," ",F9.5," ",F9.5," ",F6.3," ",F9.5," ", F6.3," ",F8.4," ",F6.3," ",F8.4," ", A3," ",A3," ",A3," ",A3," ",A3," ",A3)'
print,mdiff(i)
endfor
free_lun,OUT
end
