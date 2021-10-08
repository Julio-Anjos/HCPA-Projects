#!/bin/bash

set -e
set -o pipefail

# Synopsis
#   exec_remote [-r remote_addr] [-J hop_addr] script [params]
#
# Description
#   Executes script either locally or remotely via ssh (with hop possibile).
#
#   The options are as follows:
#
#   -r,--remote remote_addr
#
#   -J,--hop hop_addr
# 

#
# Options parsing
#

PARSED=$(getopt -o 'r:J:' --long 'remote:,hop:' -- "$@")
if test $? -ne 0
then
  exit 2
fi

eval set -- "$PARSED"
unset PARSED

remote_addr=""
hop_addr=""
while true
do
  case "$1" in
    '-r'|'--remote')
      remote_addr="$2"
      shift 2
      continue
      ;;
    '-J'|'--hop')
      hop_addr="$2"
      shift 2
      continue
      ;;
    '--')
      shift
      break
      ;;
    *)
      echo 'Missing param parsing, please report (and/or fix) this bug.'>&2
      exit 1
      ;;
  esac
done

if test -z "$remote_addr" && test -n "$hop_addr"
then
  echo 'Hop address supplied but no remote address supplied.'>&2
  exit 1
fi

#
# Argument parsing
#

shift $(($OPTIND - 1))

if test $# -lt 1
then
  echo 'No file supplied'>&2
  exit 1
fi

file="$1"
shift

if test -z "$file"
then
  echo 'Empty file supplied'>&2
  exit 1
fi

#
# Remote execution
#

if test -n "$remote_addr"
then
  if test -n "$hop_addr"
  then
    ssh -J "$hop_addr" "$remote_addr" "bash -s -- $@" <"$file"
  else
    ssh "$remote_addr" "bash -s -- $@" <"$file"
  fi
else
  "$file" "$@"
fi
