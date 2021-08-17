#!/bin/bash

# Abort on error
set -e
set -o pipefail

echo "Expected input: ./run_profile.sh cram ref"

# read vars
origin="$(pwd)"
samtools_folder_path="$(pwd)/../../samtools"
samtools="$(pwd)/../../samtools/samtools"
cram="$1"
ref="$2"

# validate input
ls -d "$samtools_folder_path"
test -n "$cram"
test -n "$ref"
ls -l "$cram"
ls -l "$ref"

# samtools setup
cd "$samtools_folder_path"
git --no-pager log --pretty=oneline --max-count=1
git stash
make clean
make -j6

# env setup
cd "$origin"
profile_path="$(pwd)/$(date +'%d_%m_%y_%H%M%S')"
mkdir $profile_path
cd $profile_path

# total time profiling
echo "Starting at $(date)..." 
time_start=$(date +%s%3N)
"$samtools" view -b -T "$ref" "$cram" >out.bam
time_end=$(date +%s%3N)
echo "total_time_ms=$((time_end - time_start))"
echo "Ended at $(date)..." 
