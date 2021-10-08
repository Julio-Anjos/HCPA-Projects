#!/bin/bash

# Synopsis
#   download_data destination source
#
# Description
#   wgets all lines from source to destination.
#

#
# Argument parsing
#

if test $# -ne 2 || test -z "$1" || test -z "$2"
then
  echo "Expected: destination source. Got: argc=$#; 1=$1; 2=$2;">&2
  exit 1
fi

ls -d "$1" 1>/dev/null 2>/dev/null
if test $? -ne 0
then
  echo "Cannot access path $1.">&2
  exit 1
fi

cd "$1"
cramlist_local="cramlist_local"
echo "Will overwrite file $cramlist_local with the requested CRAM list."
rm -f "$cramlist_local"
touch "$cramlist_local" 1>/dev/null 2>/dev/null
if test $? -ne 0
then
  echo "No write permission on $1?">&2
  exit 1
fi

ls -l "$2" 1>/dev/null 2>/dev/null
if test $? -ne 0
then
  echo "Cannot access file $2.">&2
  exit 1
fi

#
# Check for space and output local list
#

lines="$(wc -l $2 | cut -d' ' -f1)"
available="$(df -P . | tail -n 1 | awk '{ print $4}')"
available=$((available * 1024))
echo "Available space: $((available / 1024 / 1024 / 1024))G"
required=0
i=1
for file in $(cat $2)
do
  echo "Checking file sizes... $i/$lines"
  this="$(curl -sI $file | grep -i Content-Length | awk '{print $2}' | perl -pe 's/(\n|\r)//g')"
  required=$((required + this))
  bname="$(basename $file)"
  thisgbs=$((this / 1024 / 1024 / 1024))
  echo "${thisgbs}G $bname"
  echo "$(pwd)/$bname">>"$cramlist_local"
  i=$((i+1))
done
echo "Required space: $((required / 1024 / 1024 / 1024))G"
echo "Used space after download: $(echo "scale=4;$required / $available" | bc)%"

if test $required -gt $available 
then
  echo "WARNING: No space available to download everything. Proceeding anyway...">&2
fi

#
# Download data
#

i=1
for file in $(cat $2)
do
  echo "Downloading file... $i/$lines"
  wget "$file"
done
