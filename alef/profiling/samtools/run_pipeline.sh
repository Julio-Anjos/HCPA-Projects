#!/bin/bash

#
# Stage 1 - Index and view regions for each CRAM
# 
# FOR CRAM_J IN LIST DO PARALLEL
#   INDEX CRAM_J
#   FOR REGION_I IN 1,22 DO
#     VIEW CRAM_J REGION_I >CJ_RI
#
# Stage 2 - Merge CRAMs and generate VCFs for each region
#
# FOR REGION_I IN 1,22 DO PARALLEL
#   MERGE (CJ_RI FOR J IN LIST)>MERGED_I
#   INDEX MERGED_I
#   MPILEUP
#   CALL
#   BCF VIEW

#
# Setup
#

# Abort on error
set -e
set -o pipefail

source common.sh

# Get input
echo "Expected input: runtype cram_list ref"
runtype="$1"
cram_list="$2"
ref="$3"

# Validate input
ls -d "$samtools_folder_path"
test -n "$runtype"
test -n "$cram_list"
test -n "$ref"
ls -l "$cram_list"
cat "$cram_list" | xargs ls -l
ls -l "$ref"

#
# Stage 1 decl
#
function do_foreach_cram { # $1=Cram
  # Index
  cram="$1"
  echo "Indexing $cram at $(date)..."
  "$samtools" index "$cram"
  echo "Finished indexing $cram at $(date)..."

  # Setup
  index="$cram.crai"
  cram_name="${cram##*/}"
  cram_name="${cram_name%.*}"

  # View regions
  echo "Viewing regions for $cram at $(date)"
  for region in $(seq 1 22)
  do
    outname="out_region${region}_${cram_name}.bam"
    "$samtools" view -C -X "$cram" "$index" "chr$region" >"$outname"
    echo "$(pwd)/$outname">>region_list.txt
  done
  echo "Finished viewing regions for $cram at $(date)"
}

#
# Stage 2 decl
#
function do_foreach_region { # $1=Region 
  argv="$(grep region_list.txt -e region$1_ | perl -pe 's/\n/ /g')"

  # Merge
  echo "Merging region $1 at $(date)"
  "$samtools" merge -o merged_region$1.bam $argv # Do not quote argv

  # Index
  echo "Indexing region $1 at $(date)"
  "$samtools" index merged_region$1.bam

  # Clenup umerged BAMs
  echo "Removing unmerged BAMs for region $1"
  rm $argv # Do not quote argv

  # Mpileup
  echo "Mpileup region $1 at $(date)"
  "$bcftools" mpileup -Ou -o merged_region$1.bcf -f $ref merged_region$1.bam

  # Cleanup merged BAMs and their indeces - we already have the BCFs
  echo "Removing BAMs for region $1"
  rm merged_region$1.bam
  rm merged_region$1.bai

  # Call
  echo "Call region $1 at $(date)"
  "$bcftools" call -m -u -o call_merged_region$1.bcf merged_region$1.bcf

  # Cleanup uncalled BCFs
  echo "Removing uncalled BCFs"
  rm merged_region$1.bcf

  echo "View region $1 at $(date)"
  "$bcftools" view call_merged_region$1.bcf | "$vcfutils" varFilter - >final_region$1.vcf

  # Cleanup BCFs - already have the VCFs
  rm call_merged_region$1.bcf

  echo "Done region $1 at $(date)"
}

# More setup
samtools_build
bcftools_build
common_setup "pipeline_$runtype"

#
# Actually running stuff
#
echo "Starting at $(date)..."
if test "$runtype" = "seq"
then
  #
  # Sequential run 
  # 

  # Setup
  time_start=$(date +%s%3N)
  rm -f region_list.txt

  # Stage 1
  for cram in $(cat "$cram_list")
  do
    do_foreach_cram "$cram"
  done

  # Stage 2
  for i in $(seq 1 22)
  do
    do_foreach_region $i
  done

  # Report results
  time_end=$(date +%s%3N)
  echo "total_time=$((time_end - time_start))"
elif test "$runtype" = "par"
then
  #
  # Parallel run
  #

  # Setup
  time_start=$(date +%s%3N)
  rm -f region_list.txt
  export SHELL=$(type -p bash)
  export -f do_foreach_cram
  export -f do_foreach_region
  export samtools="$samtools"
  export bcftools="$bcftools"
  export vcfutils="$vcfutils"
  export ref="$ref"

  # Stage 1
  cat "$cram_list" | parallel do_foreach_cram {}

  # Stage 2
  seq 1 22 | parallel do_foreach_region {}

  # Report results
  time_end=$(date +%s%3N)
  echo "total_time=$((time_end - time_start))"
else
  echo "Unimplemented... Expecting par or seq"
fi
echo "Ending at $(date)..."
