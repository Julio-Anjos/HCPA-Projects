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
    # O comando acima gera 22 arquivos para cada CRAM inicial
    samtools merge in.bam in.bam # Não testado
    # O merge acima precisa ser do chr1 do CRAM1 com o chr1 do CRAM2
    # 22 BAMs resultantes do merge

    print("index bam …")
    int("Time used "+str(time()-start))
    os.system("samtools index " + fileout + ".bam")
    # Esse index tem que ser em cima dos 22 BAMs resultantes
    # Talvez tenha uma versão do samtools que faça isso automaticamente

    print("It’s mpileup time. Generating bcf file…")
    print("Time used "+str(time()-start))
    os.system("bcftools mpileup -O b -o " + fileout + ".bcf -f ../ref/GRCh38_full_analysis_set_plus_decoy_hla.fa " + fileout + ".bam") 
    # Também para cada um dos 22 BAMs

    print("Variant calling …")
    print("Time used "+time()-start))
    os.system("bcftools call -m -u -o " + "call" + fileout + ".bcf " + fileout + ".bcf")
    # Também para cada um dos 22 BAMs

    print("Generating final vcf ...")
    print("Time used "+str(time()-start))
    os.system("bcftools view " + "call" + fileout + ".bcf | vcfutils.pl varFilter - > " + "final" + fileout + ".vcf")
    # Também para cada um dos 22 BAMs

    # Vamos acabar com 22 VCFs

  print("bye")
  
# Depois disso tem mais coisa
# Baixar o plink https://en.wikipedia.org/wiki/PLINK_(genetic_tool-set)

# Fazer com 2 CRAMs de cada uma das 3 pops, um para cada pop.
