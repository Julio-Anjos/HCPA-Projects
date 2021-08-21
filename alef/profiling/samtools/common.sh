#
# Common
#

origin="$(pwd)"
samtools_folder_path="$(pwd)/../../samtools"
samtools="$(pwd)/../../samtools/samtools"

function samtools_build {
  cd "$samtools_folder_path"
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
