#!/bin/bash

# Synopsis
#   prepare.sh [-J hop_addr] [-l local_list] remote_addr remote_path
#
# Description
#   Prepares the remote environment for execution.
#
#   The options are as follows:
#
#   -J,--hop hop_addr
#     Jump through this address to reach the remote address.
#
#   -l,--local local_list
#     Copy this local CRAM list to the remote path at the remote address.
#

#echo "$(basename $0): Started with params: $@"

#
# Options parsing
#

PARSED=$(getopt -o 'J:l:' --long 'hop:,local:' -- "$@")
if test $? -ne 0
then
  exit 2
fi

eval set -- "$PARSED"
unset PARSED

local_list=""
hop_addr=""
while true
do
  case "$1" in
    '-l'|'--local')
      local_list="$2"
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

#
# Argument parsing
#

shift $(($OPTIND - 1))

if test $# -lt 2
then
  echo 'No remote address or path supplied'>&2
  exit 1
fi

remote_host="$1"
remote_path="$2"
copy_cmd="scp"
if test -n "$hop_addr"
then
  copy_cmd="$copy_cmd -J $hop_addr"
fi

#
# Copy necessary files to remote host:remote path
#

"$copy_cmd" prepare_docker.sh "$remote_host:$remote_path" 1>/dev/null
"$copy_cmd" download_data.sh "$remote_host:$remote_path" 1>/dev/null
"$copy_cmd" variant_call.sh "$remote_host:$remote_path" 1>/dev/null
if test -f samgui.filter
then
  "$copy_cmd" samgui.filter "$remote_host:$remote_path" 1>/dev/null
fi
if test -n "$local_list"
then
  "$copy_cmd" "$local_list" "$remote_host:$remote_path" 1>/dev/null
fi
