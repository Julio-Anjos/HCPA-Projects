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

function do_foreach_cram {
  cram="$1"
  echo "Indexing $cram at $(date)..."
  "$samtools" index "$cram"
  echo "Finished indexing $cram at $(date)..."
  index="$cram.crai"
  cram_name="${cram##*/}"
  cram_name="${cram_name%.*}"
  echo "Viewing regions for $cram at $(date)"
  for region in $(seq 1 22)
  do
    outname="out_region${region}_${cram_name}.bam"
    "$samtools" view -C -X "$cram" "$index" "chr$region" >"$outname"
    echo "$(pwd)/$outname">>region_list.txt
  done
  echo "Finished viewing regions for $cram at $(date)"
}

function do_foreach_region { # Region filelist
  argv="$(grep region_list.txt -e region$1_ | perl -pe 's/\n/ /g')"
  "$samtools" merge "$argv">merged_region$1.bam
  "$samtools" index merged_region$1.bam
}

# Start

samtools_build
common_setup "pipeline_$runtype"

echo "Starting at $(date)..."
if test "$runtype" = "seq"
then
  time_start=$(date +%s%3N)
  rm -f region_list.txt
  for cram in $(cat "$cram_list")
  do
    do_foreach_cram "$cram"
  done
  for i in $(seq 1 22)
  do
    do_foreach_region $i
  done
  time_end=$(date +%s%3N)
  echo "total_time=$((time_end - time_start))"
elif test "$runtype" = "par"
then
  rm -f region_list.txt
  export SHELL=$(type -p bash)
  export -f do_foreach_cram
  export -f do_foreach_region
  export samtools=$samtools
  cat "$cram_list" | parallel do_foreach_cram {}
  seq 1 22 | parallel do_foreach_region {}
else
  echo "Unimplemented... Expecting par or seq"
fi
echo "Ending at $(date)..."
