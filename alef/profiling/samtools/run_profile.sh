#!/bin/bash

# Abort on error
set -e
set -o pipefail

echo "Expected input: ./run_profile.sh steps cram ref"

# read vars
origin="$(pwd)"
samtools_folder_path="$(pwd)/../../samtools"
samtools="$(pwd)/../../samtools/samtools"
run="$1"

# check what to do
case $run in
  "all")
  echo "Unimplemented."
  exit 1
  ;;

  "view")
    f_input="view_input"
    f_validate="view_validate"
    f_build="view_build"
    f_setup="view_setup"
    f_profile="view_profile"
  ;;

  "index" )
  echo "Unimplemented."
  exit 1
  ;;

  *)
  echo "Unimplemented."
  exit 1
  ;;
esac

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

function view_build {
  cd "$samtools_folder_path"
  git --no-pager log --pretty=oneline --max-count=1
  git stash
  make clean
  make -j6
}

function view_setup {
  # env setup
  cd "$origin"
  profile_path="$(pwd)/$(date +'%d_%m_%y_%H%M%S')"
  mkdir $profile_path
  cd $profile_path
}

function view_profile {
  # total time profiling
  time_start=$(date +%s%3N)
  "$samtools" view -b -T "$ref" "$cram" >out.bam
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
$f_setup
echo "Profiling... It is $(date)"
$f_profile
echo "Done... It is $(date)" 


