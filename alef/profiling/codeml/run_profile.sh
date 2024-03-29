#/bin/bash

# Abort on error
set -e
set -o pipefail

################################################################################
#
# Variables section - change according to the experiment being run.
#
################################################################################

#
# Profile type to run
#
# total_time - Just end-start
# gprof - Profile with gprof
# callgrind - Profile with Valgrind 
#
PROFILE_TYPE="$1"
case $PROFILE_TYPE in
  "gprof")
    CFLAGS="-pg"
  ;;

  "callgrind")
    CFLAGS="-g"
  ;;

  "total_time" )
    CFLAGS=""
  ;;

  *)
  echo "Unimplemented."
  exit 1
  ;;
esac

#
# Project to use
#
# codeml - original from PAML
# slim - SlimCodeML from selectome's FTP
# fast - FastCodeML from gitlab
#
PROJECT="$3"
case $PROJECT in
  "codeml")
    PATH_SRC="$(pwd)/../paml/src"
    CMD_BUILD="make clean && make"
    PATH_EXE="$PATH_SRC/codeml"
  ;;

 "slim")
    PATH_SRC="$(pwd)/../slimcodeml"
    CMD_BUILD="rm -rf b && mkdir b && cd b && cmake .. && make"
    PATH_EXE="$PATH_SRC/b/slimcodeml"
  ;;

  "fast")
    PATH_SRC="$(pwd)/../fastcodeml"
    CMD_BUILD="rm -rf b && mkdir b && cd b && cmake .. && make"
    PATH_EXE="$PATH_SRC/b/fast"
  ;;

  *)
    echo "Please choose project to use"
    exit 1
  ;;
esac

#
# Path to PAML
#

#
# Path to experiment data (sequence and tree files)
#
NAME_DATA="$2"
PATH_DATA="$(pwd)/../data/$NAME_DATA"

#
# Run dirname 
# This directory will be created within the data dir to store the run results 
#
PATH_RUN="$(pwd)/${NAME_DATA}_${PROJECT}_${PROFILE_TYPE}_$(date +'%d_%m_%y_%H%M%S')"

#
# codeml config file to use
#
FILE_CTL="codeml.ctl"

################################################################################
#
# Validate dirs and ask for user confirmation before starting
#
################################################################################
ls -d "$PATH_SRC"
ls -d "$PATH_DATA"
echo
echo "Starting in 5s from $(hostname) at $PATH_RUN"
echo
sleep 5

################################################################################
#
# Env. setup: cleanup, git SHA1, compilation, directory creation, etc
#
################################################################################
cd "$PATH_SRC"
git stash
git clean -ffx
git status -s
git diff -p
git --no-pager log --pretty=oneline --max-count=1
eval "$CMD_BUILD"

mkdir "$PATH_RUN"
ln -s "$PATH_DATA"/* "$PATH_RUN/" 
cd "$PATH_RUN"
ln -s "$PATH_EXE" codeml

################################################################################
#
# Profile run
#
################################################################################
echo "Running $PROFILE_TYPE from $(pwd)..."
case $PROFILE_TYPE in
  "total_time")
    time_start=$(date +%s%3N)
    ./codeml "$FILE_CTL"
    time_end=$(date +%s%3N)
    echo "total_time_ms=$((time_end - time_start))">results.csv
  ;;

  "gprof")
    ./codeml "$FILE_CTL"
  ;;


  "callgrind")
    valgrind --tool=callgrind ./codeml "$FILE_CTL"
  ;;

  *)
  echo "Unimplemented."
  ;;
esac
