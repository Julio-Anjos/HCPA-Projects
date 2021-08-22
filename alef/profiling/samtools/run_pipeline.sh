#!/bin/bash

# Abort on error
set -e
set -o pipefail

source common.sh

# Input
echo "Expected input: runtype cram_list"
runtype="$1"
cram_list="$2"

# Validate
ls -d "$samtools_folder_path"
test -n "$runtype"
test -n "$cram_list"
ls -l "$cram_list"
cat "$cram_list" | xargs ls -l

function do_foreach_region_seq {
  for region in $(seq 1 22)
  do
    "$samtools" view -C -X "$cram" "$index" "chr$region" >"out_region${region}_${cram_name}.bam"
  done
}

function do_foreach_region_par {
  seq 1 23 | parallel
    "$samtools" view -C -X "$cram" "$index" "chr{}" >"out_region{}_${cram_name}.bam"
}

function do_foreach_cram {
  cram="$1"
  doregion="$2"
  echo "Indexing $cram at $(date)..."
  "$samtools" index "$cram" 
  echo "Finished indexing $cram at $(date)..."
  index="$cram.crai"
  cram_name="${cram##*/}"
  cram_name="${cram_name%.*}"
  echo "Viewing regions for $cram at $(date)"
  $doregion 
  echo "Finished viewing regions for $cram at $(date)"
}

# Start

samtools_build
common_setup "pipeline_$runtype"

echo "Starting at $(date)..."
if test "$runtype" = "seq"
then
  time_start=$(date +%s%3N)
  for cram in $(cat "$cram_list")
  do
    do_foreach_cram "$cram" "do_foreach_region_seq"
  done
  time_end=$(date +%s%3N)
  echo "total_time=$((time_end - time_start))"
elif test "$runtype" = "par" 
then
  export SHELL=$(type -p bash)
  export -f do_foreach_cram
  #export -f do_foreach_region_par
  export -f do_foreach_region_seq
  export samtools=$samtools
  cat "$cram_list" | parallel do_foreach_cram {} "do_foreach_region_seq"
else
  echo "Unimplemented... Expecting par or seq"
fi
echo "Ending at $(date)..."
