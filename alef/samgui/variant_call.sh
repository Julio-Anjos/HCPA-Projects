#!/bin/bash

#
# Stage 1 - Index and view regions for each CRAM
#
# FOR CRAM_J IN LIST DO PARALLEL
#   INDEX CRAM_J
#   FOR REGION_I IN 1,22 DO
#     VIEW CRAM_J REGION_I >CJ_RI
#
# Stage 2 - Merge CRAMs, generate and filter VCFs for each region
#
# FOR REGION_I IN 1,22 DO PARALLEL
#   MERGE (CJ_RI FOR J IN LIST)>MERGED_I
#   INDEX MERGED_I
#   MPILEUP
#   CALL
#   BCF VIEW
#   VCF REMOVE INDELS
#   VCF FILTER
#
# Stage 3 - Merge and filter VCFs
#
# VCF CONCAT
# BCF VIEW
# BCF INDEX
# BCF ANNOTATE
# BCF VIEW
# VCF FILTER

#
# Setup
#

# Abort on error (enable only after argp for pretty error reporting)
#set -e
#set -o pipefail

if test $# -lt 2 || test -z "$1" || test -z "$2"
then
  echo "Expected input: origin cram_list" >&2
  exit 1
fi

ls -d "$1" 1>/dev/null 2>/dev/null
if test $? -ne 0
then
  echo "Could not locate origin $1." >&2
  exit 1
fi
cd "$1"

samtools_folder_path="$(pwd)/samtools"
samtools="$samtools_folder_path/samtools"

bcftools_folder_path="$(pwd)/bcftools"
bcftools="$bcftools_folder_path/bcftools"

vcftools_folder_path="$(pwd)/vcftools"
vcftools="$vcftools_folder_path/src/cpp/vcftools"
vcftools_concat="$vcftools_folder_path/src/perl/vcf-concat"
export PERLLIB="$vcftools_folder_path/src/perl:$PERLLIB"

vcfutils="$bcftools_folder_path/misc/vcfutils.pl"

ls -d "$samtools_folder_path" 1>/dev/null 2>/dev/null
if test $? -ne 0
then
  echo "Could not locate samtools folder path at $samtools_folder_path." >&2
  exit 1
fi

ls -d "$bcftools_folder_path" 1>/dev/null 2>/dev/null
if test $? -ne 0
then
  echo "Could not locate bcftools folder path at $bcftools_folder_path." >&2
  exit 1
fi

function samtools_build {
  cd "$samtools_folder_path"
  #git --no-pager log --pretty=oneline --max-count=1
  #git stash
  make clean
  make -j6
}

function bcftools_build {
  cd "$bcftools_folder_path"
  #git --no-pager log --pretty=oneline --max-count=1
  #git stash
  make clean
  make -j6
}

function vcftools_build {
  cd "$vcftools_folder_path"
  #git --no-pager log --pretty=oneline --max-count=1
  #git stash
  ./autogen.sh
  ./configure
  make clean
  make -j6
}

function common_setup {
  # env setup
  cd "$origin"
  profile_path="$(pwd)/$1_$(date +'%d_%m_%y_%H%M%S')"
  mkdir "$profile_path"
  cd "$profile_path"
}

#
# Argument parsing
#

cram_list="$2"
ls -l "$cram_list" 1>/dev/null 2>/dev/null
if test $? -ne 0
then
  echo "Could not access cram list at $cram_list" >&2
  exit 1
fi

for file in $(cat "$cram_list")
do
  ls -l "$file" 1>/dev/null 2>/dev/null
  if test $? -ne 0
  then
    echo "Could not access file $file from cram list." >&2
    exit 1
  fi
done

ref="$(grep $cram_list -Pie '(\.fa|\.fasta)(\.gz)?$')"
if test $? -ne 0
then
  echo "Could not find reference genome on FASTA format on cram list." >&2
  exit 1
fi

vcfref="$(grep $cram_list -Pie '\.vcf\.gz$')"
if test $? -ne 0
then
  echo "Could not find VCF reference (.vcf.gz) file on cram list." >&2
  exit 1
fi

vcfrefidx="$(grep $cram_list -Pie '\.vcf\.gz\.(tbi|csi)$')"
if test $? -ne 0
then
  echo "Could not find VCF reference index file on cram list." >&2
  exit 1
fi

# Abort on error
set -e
set -o pipefail

# Separate reference files from CRAMs
cram_list_actual="$(mktemp)"
grep "$cram_list" -Pie '\.cram$'>"$cram_list_actual"
cram_list="$cram_list_actual"

#
# Stage 1 decl
#

function do_stage1 { # $1=Cram
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
    outname="out_region${region}_${cram_name}.cram"
    "$samtools" view -C -X "$cram" "$index" "chr$region" >"$outname"
    echo "$(pwd)/$outname">>region_list.txt
  done
  echo "Finished viewing regions for $cram at $(date)"
}

#
# Stage 2 decl
#

function do_stage2 { # $1=Region
  argv="$(grep region_list.txt -e region$1_ | perl -pe 's/\n/ /g')"

  # Merge
  echo "Merging region $1 at $(date)"
  "$samtools" merge -o merged_region$1.cram $argv # Do not quote argv

  # Index
  echo "Indexing region $1 at $(date). Used $(du -hs)"
  "$samtools" index merged_region$1.cram

  # Clenup umerged CRAMs
  echo "Removing unmerged CRAMs for region $1"
  rm $argv # Do not quote argv

  # Mpileup
  echo "Mpileup region $1 at $(date). Used $(du -hs)"
  "$bcftools" mpileup -Ou -o merged_region$1.bcf -f $ref merged_region$1.cram

  # Cleanup merged CRAMs and their indeces - we already have the BCFs
  echo "Removing CRAMs for region $1. Used $(du -hs)"
  rm -f merged_region$1.cram
  rm -f merged_region$1.crai
  rm -f merged_region$1.cram.crai

  # Call
  echo "Call region $1 at $(date). Used $(du -hs)"
  "$bcftools" call -m -o call_merged_region$1.bcf merged_region$1.bcf

  # Cleanup uncalled BCFs
  echo "Removing uncalled BCFs. Used $(du -hs)"
  rm merged_region$1.bcf

  # Convert to VCF + filter. This is necessary even though VCFtools accepts BCF
  echo "View region $1 at $(date). Used $(du -hs)"
  "$bcftools" view call_merged_region$1.bcf | "$vcfutils" varFilter - >region$1.vcf

  # Cleanup BCFs - already have the VCFs
  rm call_merged_region$1.bcf

  # Remove indels
  # OBS: Perhaps this could be replaced this with --skip-indels at mpileup time
  # but this command is pretty fast (3s), so it was not tested. Removing indels
  # early on did not seem to improve performance or reduce output size...
  echo "Removing indels for region $1 at $(date). Used $(du -hs)"
  "$vcftools" --vcf region$1.vcf --remove-indels --recode --recode-INFO-all --out region$1_noindels

  # Cleanup VCFs
  echo "Removing VCFs with indels for region $1 at $(date). Used $(du -hs)"
  rm region$1.vcf

  # Filter VCFs
  echo "Filtering VCF for region $1 at $(date). Used $(du -hs)"
  "$vcftools" --vcf region$1_noindels.recode.vcf --max-missing 0.5 --minDP 5 --min-alleles 2 --max-alleles 2 --minQ 20 --recode --recode-INFO-all --out region$1_filtered

  # Cleanup VCFs
  echo "Removing unfiltered VCFs for region $1 at $(date). Used $(du -hs)"
  rm region$1_noindels.recode.vcf

  echo "Done region $1 at $(date). Used $(du -hs)"
}

#
# Stage 3 decl
#
function do_stage3 {
  argv="$(seq 1 22 | xargs -I'{}' echo $(pwd)/region{}_filtered.recode.vcf | perl -pe 's/\n/ /g')"

  # Concat
  echo "Cat regions at $(date). Used $(du -hs)"
  "$vcftools_concat" $argv >final.vcf # Do not quote argv

  # Cleanup
  echo "Rm uncat regions at $(date). Used $(du -hs)"
  rm region*_filtered.recode.vcf

  # Zip
  # OBS: We did not output zipped before because vcf-concat can't handle it.
  # We zip it here instead of using unzipped ref because the ref is too big.
  echo "Zip final VCF at $(date). Used $(du -hs)"
  "$bcftools" view final.vcf -Oz -o final.vcf.gz

  # Clenaup
  echo "Rm unzipped vcf at $(date). Used $(du -hs)"
  rm region*_filtered.vcf

  # Index
  echo "Index final VCF at $(date). Used $(du -hs)"
  "$bcftools" index final.vcf.gz

  # Make sure we have the reference index
  if test "$(dirname $vcfrefidx)" != "$(pwd)"
  then
    ln -s $vcfrefidx
  fi

  # Annotate
  echo "Annotate final VCF at $(date). Used $(du -hs)"
  "$bcftools" annotate -c ID -a "$vcfref" final.vcf.gz >finalrsID.vcf.gz

  # Unzip
  echo "Convert final VCF at $(date). Used $(du -hs)"
  "$bcftools" view finalrsID.vcf.gz -Ov -o finalrsID.vcf
}


# More setup
samtools_build
bcftools_build
vcftools_build
common_setup "samgui"

#
# Actually running stuff
#

echo "Starting at $(date)... Space used by our pipeline: $(du -hs)"
#
# Parallel run
#

# Setup
time_start=$(date +%s%3N)
rm -f region_list.txt
export SHELL=$(type -p bash)
export -f do_stage1
export -f do_stage2
export samtools="$samtools"
export bcftools="$bcftools"
export vcftools="$vcftools"
export vcftools_concat="$vcftools_concat"
export vcfutils="$vcfutils"
export ref="$ref"

# Stage 1
echo "Starting stage 1 at $(date)."
cat "$cram_list" | parallel do_stage1 {}
echo "Ended stage 1 at $(date). Used $(du -hs)"

# Stage 2
echo "Starting stage 2 at $(date)."
seq 1 22 | parallel do_stage2 {}
echo "Ended stage 2 at $(date). Used $(du -hs)"

# Stage 3
echo "Starting stage 3 at $(date)."
do_stage3
echo "Ended stage 3 at $(date). Used $(du -hs)"

# Report results
time_end=$(date +%s%3N)
echo "total_time=$((time_end - time_start))"
echo "Ending at $(date)... Space used by our pipeline: $(du -hs)"
