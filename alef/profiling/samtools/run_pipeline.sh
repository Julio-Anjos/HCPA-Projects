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

# Function to run in parallel
do_foreach_cram() {
  cram="$1"
  echo "Indexing $cram at $(date)..."
  "$samtools" index "$cram" 
  echo "Finished indexing $cram at $(date)..."
  index="$cram.crai"
  cram_name="$(basename -s $cram)"
  
  echo "Viewing regions for $cram at $(date)"
  for region in $(seq 1 22)
  do
    "$samtools" view -C -X "$cram" "$index" "chr$region" >"out_region${region}_${cram_name}.bam"
  done
  echo "Finished viewing regions for $cram at $(date)"
}

# Start

samtools_build
common_setup "pipeline_$run"

echo "Starting at $(date)..."
if test "$runtype" = "seq"
then
  time_start=$(date +%s%3N)
  for cram in $(cat "$cram_list")
  do
    do_foreach_cram "$cram"
  done
  time_end=$(date +%s%3N)
  echo "total_time=$((time_end - time_start))"
else if test "$runtype" = "par" then
  export SHELL=$(type -p bash)
  export -f do_foreach_cram
  cat "$cram_list" | parallel do_foreach_cram
else
  echo "Unimplemented..."
fi
echo "Ending at $(date)..."
