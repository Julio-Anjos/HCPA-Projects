#!/bin/python 
import sys 
import os
from time import time

if  __name__="__main__":
  start = time()
  filename=sys.argv[1]
  file_ext=filename.split(".")
  filebam=file_ext+".bam"
  os.system("samtools view -b -T " + ../ref/GRCh38_full_analysis_set_plus_decoy_hla.fa  + file_ext[0] + ".bam" ) 
  if(os.system('samtools view -h ‘+ filebam +’ | grep "coordinate"')!=0):
    print("sorting "+ filebam)
    os.system("samtools sort -o " + filebam + ".sorted "+ filebam)
    filebam=filebam+".sorted"
  os.system("samtools index " + filebam)
  list_file = [str(i) for i in range(1,23)]
  # bam split - every split file have header
  for i in list_file:
    fileout = filebam +  "Chr" + i 
    print("spliting chromosome " + i + " ...")
    print("Time used "+str(time()-start))
    os.system("samtools view -b " + filebam + " chr" + i + " > "+ fileout + ".bam")
    print("index bam …")
    int("Time used "+str(time()-start))
    os.system("samtools index " + fileout + ".bam")
    samtools merge in.bam in.bam # Não testado
    print("It’s mpileup time. Generating bcf file…")
    print("Time used "+str(time()-start))
    os.system("bcftools mpileup -O b -o " + fileout + ".bcf -f ../ref/GRCh38_full_analysis_set_plus_decoy_hla.fa " + fileout + ".bam") 
    print("Variant calling …")
    print("Time used "+time()-start))
    os.system("bcftools call -m -u -o " + "call" + fileout + ".bcf " + fileout + ".bcf")
    print("Generating final vcf ...")
    print("Time used "+str(time()-start))
    os.system("bcftools view " + "call" + fileout + ".bcf | vcfutils.pl varFilter - > " + "final" + fileout + ".vcf")
  print("bye")
  
