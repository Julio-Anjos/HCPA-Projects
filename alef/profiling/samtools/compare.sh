#!/bin/bash

set -e
set -o pipefail

source common.sh

# Converte os dois para SAM e compara textualmente
echo "Expected input: BAM CRAM"

ls -d "$samtools_folder_path"
ls "$1"
ls "$2"

samtools_build

common_setup "cmp"

"$samtools" view "$1" >1.sam
"$samtools" view "$2" >2.sam

echo "Running diff... It is $(date)"
diff -q 1.sam 2.sam
echo "Ended with result $?. It is $(date)"
