#!/bin/bash

# Synopsis
#   exec_docker image_name data_source script [params]
#
# Description
#   Executes script on image_name with /DATA bound to data_source on the host, starting it if not running
#

#
# Argument parsing
#

if test $# -lt 3 || test -z "$1" || test -z "$2" || test -z "$3"
then
  echo "Expected: image_name data_source script params">&2
  exit 1
fi

ls -ld "$2" 1>/dev/null 2>/dev/null
if test $? -ne 0
then
  echo "Cannot access path $2.">&2
  exit 1
fi

if test "$2" == "${2#/}"
then
  echo "$2 is not an absolute path">&2
  exit 1
fi

ls -l "$3" 1>/dev/null 2>/dev/null
if test $? -ne 0
then
  echo "Cannot access file $3.">&2
  exit 1
fi

#
# Start if not running
#

image_name="$1"
docker ps | grep samgui
if test $? -ne 0
then
  # TODO volumes support, or at least custom target name, don't rely on /DATA being available
  # TODO custom image name, don't rely on samgui being available
  docker run --name samgui --mount type=bind,source="$2",target=/DATA -it -d "$image_name"
fi

#
# Execute on docker
#

cmd="$3"
shift 3
docker exec samgui bash $cmd $@
