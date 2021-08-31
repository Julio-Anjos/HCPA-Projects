#
# Common
#

origin="$(pwd)"

samtools_folder_path="$(pwd)/../../samtools"
samtools="$samtools_folder_path/samtools"

bcftools_folder_path="$(pwd)/../../bcftools"
bcftools="$bcftools_folder_path/bcftools"

vcfutils="$bcftools_folder_path/misc/vcfutils.pl"

function samtools_build {
  cd "$samtools_folder_path"
  git --no-pager log --pretty=oneline --max-count=1
  git stash
  make clean
  make -j6
}

function bcftools_build {
  cd "$bcftools_folder_path"
  git --no-pager log --pretty=oneline --max-count=1
  git stash
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
