#!/bin/bash

if test $# -lt 2 || test -z "$1"
then
  echo "Expected: prepare.sh remote_host [hop_host]">&2
  exit 1
fi

if test -n "$2"
then
  scp -J "$2" download_data.sh "$1:/DATA/alef/samgui_test/"
  scp -J "$2" variant_call.sh "$1:/DATA/alef/samgui_test/"
  scp -J "$2" cramlist_remote "$1:/DATA/alef/samgui_test/"
else
  scp download_data.sh "$1:/DATA/alef/samgui_test/"
  scp variant_call.sh "$1:/DATA/alef/samgui_test/"
  scp cramlist_remote "$1:/DATA/alef/samgui_test/"
fi
