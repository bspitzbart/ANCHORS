pro match_comeron
 
readcol,'/data/swolk/OBSERVATIONS/XRAY/RCW108/IR/rcw108_nirPhotom.deg.dat', $
  n,ra,dec,j_m,j_err,h_m,h_err,k_m,k_err, $
  format='f,f,f,f,f,f,f,f,f', skipline=3
rdfloat,'../04503/Data/obs4503/sources_ra_dec.txt',bnum,num,bra,bdec,skipline=4

bra_hr=bra/360.0*24.0
ra_hr=ra/360.0*24.0
match=lonarr(n_elements(bra))
mdiff=fltarr(n_elements(bra))
gcirc,1,bra_hr,bdec,249.99454304232/360.0*24.0,-48.865044769556,offax
for i=0,n_elements(bra)-1 do begin
  print,i
  gcirc,1,bra_hr(i),bdec(i),ra_hr,dec,diff
  mdiff(i)=min(diff,m)
  match(i)=m
endfor

ra =[ra,0]
dec =[dec,0]
j_m =[j_m,0]
j_err =[j_err,0]
h_m =[h_m,0]
h_err =[h_err,0]
k_m =[k_m,0]
k_err =[k_err,0]
 
openw,OUT,'match_comeron.out',/get_lun
printf,OUT,"xr_ra xr_dec xr_offax ir_ra ir_dec offset j_m j_err h_m h_err k_m k_err"
for i=0,n_elements(match)-1 do begin
  printf,OUT,bra(i),bdec(i),offax(i),ra(match(i)),dec(match(i)), $
             mdiff(i), $
             j_m(match(i)),j_err(match(i)), $
             h_m(match(i)),h_err(match(i)), $
             k_m(match(i)),k_err(match(i)), $
             format='(F9.5," ",F9.5," ",F9.5," ",F9.5," ",F9.5," ",F9.5," ",F6.3," ",F9.5," ", F6.3," ",F8.4," ",F6.3," ",F8.4)'
print,mdiff(i)
endfor
free_lun,OUT
end
