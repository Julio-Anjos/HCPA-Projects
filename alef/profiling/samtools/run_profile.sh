#!/bin/bash

# Abort on error
set -e
set -o pipefail

source common.sh

# read vars
run="$1"
# check what to do
case $run in
  "all")
  echo "Unimplemented."
  exit 1
  ;;

  "view")
    echo "Expected input: ./run_profile.sh view cram ref"
    f_input="view_input"
    f_validate="view_validate"
    f_build="samtools_build"
    f_setup="common_setup"
    f_profile="view_profile"
  ;;

  "index" )
    echo "Expected input: ./run_profile.sh index (bam|cram)"
    f_input="index_input"
    f_validate="index_validate"
    f_build="samtools_build"
    f_setup="common_setup"
    f_profile="index_profile"
  ;;

  "view_region" )
    echo "Expected input: ./run_profile.sh view_region (bam|cram) index region"
    f_input="view_region_input"
    f_validate="view_region_validate"
    f_build="samtools_build"
    f_setup="common_setup"
    f_profile="view_region_profile"
  ;;

  "bcftools" )
    echo "Expected input: ./run_profile.sh bcftools merged_indexed_region.bam ref (u|b)"
    f_input="bcftools_input"
    f_validate="bcftools_validate"
    f_build="bcftools_build"
    f_setup="common_setup"
    f_profile="bcftools_profile"
  ;;

  *)
  echo "Unimplemented."
  exit 1
  ;;
esac

#
# View
#

function view_input {
  cram="$2"
  ref="$3"
}

function view_validate {
  ls -d "$samtools_folder_path"
  test -n "$cram"
  test -n "$ref"
  ls -l "$cram"
  ls -l "$ref"
}

function view_profile {
  # total time profiling
  time_start=$(date +%s%3N)
  "$samtools" view -b -T "$ref" "$cram" >out.bam
  time_end=$(date +%s%3N)
  echo "total_time_ms=$((time_end - time_start))"
}

# Region

function view_region_input {
  cram="$2"
  index="$3"
  region="$4"
}

function view_region_validate {
  ls -d "$samtools_folder_path"
  test -n "$cram"
  test -n "$index"
  test $region -ge 0
  ls -l "$cram"
  ls -l "$index"
}

function view_region_profile {
  # total time profiling
  time_start=$(date +%s%3N)
  "$samtools" view -b -X "$cram" "$index" "chr$region" >"out_region$region.bam"
  time_end=$(date +%s%3N)
  echo "total_time_ms=$((time_end - time_start))"
}

#
# Index
#

function index_input {
  bam="$2"
}

function index_validate {
  ls -d "$samtools_folder_path"
  test -n "$bam"
  ls -l "$bam"
}

function index_profile {
  time_start=$(date +%s%3N)
  "$samtools" index "$bam" 
  time_end=$(date +%s%3N)
  echo "total_time_ms=$((time_end - time_start))"
}

#
# bcftools
#

function bcftools_input {
  bam="$2"
  ref="$3"
  outtype="$4"
}

function bcftools_validate {
  ls -d "$bcftools_folder_path"
  test -n "$bam"
  ls -l "$bam"
  test -n "$ref"
  ls -l "$ref"
}

function bcftools_profile {
  echo "outtype=$outtype"
  time_start=$(date +%s%3N)

  "$bcftools" mpileup -O "$outtype" -o out.bcf -f "$ref" "$bam"
  "$bcftools" call -m -u -o call_out.bcf out.bcf
  "$bcftools" view call_out.bcf >/dev/null

  time_end=$(date +%s%3N)
  echo "total_time_ms=$((time_end - time_start))"
}

echo "Get input..."
$f_input "$@"
echo "Validate input..."
$f_validate
echo "Build samtools..."
$f_build
echo "Setup run env..."
$f_setup "$1"
echo "Profiling... It is $(date)"
$f_profile
echo "Done... It is $(date)" 


