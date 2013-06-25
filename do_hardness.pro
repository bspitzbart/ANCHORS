pro do_hardness
sft=mrdfits('../04503/dmex_sft.fits',1)
med=mrdfits('../04503/dmex_med.fits',1)
hrd=mrdfits('../04503/dmex_hrd.fits',1)
hrd(where(hrd.net_counts lt 0)).net_counts=0
med(where(med.net_counts lt 0)).net_counts=0
sft(where(sft.net_counts lt 0)).net_counts=0
hr1=(med.net_counts-sft.net_counts)/(med.net_counts+sft.net_counts)
hr2=(hrd.net_counts-sft.net_counts)/(hrd.net_counts+sft.net_counts)
hr3=(hrd.net_counts-med.net_counts)/(hrd.net_counts+med.net_counts)
openw,ounit,"../04503/do_hardness.out",/get_lun
for i=0,n_elements(hr1)-1 do begin
  printf,ounit,i+1,hr1(i),hr2(i),hr3(i),format='(I4,3(" ",F7.4))'
endfor
free_lun,ounit
end 
