#!/bin/bash

echo "$(basename $0): Started with params: $@"

# Synopsis
#   exec_docker start_container image_name data_source script [params]
#
# Description
#   Executes script on image_name with /DATA bound to data_source on the host, starting it if not running
#

#
# Argument parsing
#

if test $# -lt 4 || test -z "$1" || test -z "$2" || test -z "$3" || test -z "$4"
then
  echo "Expected: start_container image_name data_source script params">&2
  exit 1
fi

data_source="$3"
if ! test -d "$data_source"
then
  echo "Cannot access path $data_source.">&2
  exit 1
fi

if test "$data_source" == "${data_source#/}"
then
  echo "$data_source is not an absolute path">&2
  exit 1
fi

#
# Start if not running
#

image_name="$2"
docker ps | grep samgui
if test $? -ne 0 
then
  if test "$1" = "y"
  then
    docker run --name samgui --mount type=bind,source="$data_source",target=/DATA -it -d "$image_name"
  else
    echo "Docker not running and requested not to run. 1=$1" >&2
    exit 1
  fi
fi

#
# Execute on docker
#

cmd="$4"
shift 4

if test -f "$cmd"
then
  docker exec samgui bash $cmd $@
else
  docker exec samgui $cmd $@
fi

