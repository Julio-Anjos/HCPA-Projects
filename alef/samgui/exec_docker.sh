#!/bin/bash

# Synopsis
#   exec_docker image_name script [params]
#
# Description
#   Executes script on image_name, starting it if not running
#

#
# Argument parsing
#

if test $# -lt 2 || test -z "$1" || test -z "$2"
then
  echo "Expected: image_name script params">&2
  exit 1
fi

ls -l "$2"
if test $? -ne 0
then
  echo "Cannot access file $2.">&2
  exit 1
fi

#
# Start if not running
#

image_name="$1"
docker ps | grep samgui
if test $? -ne 0
then
  # TODO either use a volume or allow for optparse to define the mount point
  docker run --name samgui --mount type=bind,source=/DATA,target=/DATA -it -d "$image_name"
fi

#
# Execute on docker
#

cmd="$2"
shift 2
docker exec samgui bash $cmd $@
