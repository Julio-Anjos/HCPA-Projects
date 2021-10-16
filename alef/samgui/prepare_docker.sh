#!/bin/bash

echo "$(basename $0): Started with params: $@"

# preapre_docker.sh image_name

if test $# -ne 1 || test -z "$1"
then
  echo "Image name not supplied." >&2
  exit 1
fi

docker run hello-world
if test $? -ne 0
then
  echo "Failed to launch docker hello-world with error code $?. Try checking the following things:" >&2
  echo ""
  echo "1. Is docker installed?" >&2
  echo "2. Does the remote user have permission to run docker?" >&2
  echo "3. Is the hello-world image present (did you install docker from upstream)?" >&2
  exit 1
fi

docker images | grep "$1"
if test $? -ne 0
then
  echo "Image $1 not found, trying to pull it." >&2
  docker pull "$1"
  if test $? -ne 0
  then
    echo "Could not pull $1." >&2
    exit 1
  fi
fi
