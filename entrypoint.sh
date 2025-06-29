#!/bin/bash
set -e

SOCK=/var/run/docker.sock

if [ -S "$SOCK" ]; then
  DOCKER_GID=$(stat -c '%g' "$SOCK")
  if ! getent group docker >/dev/null; then
    groupadd -g "$DOCKER_GID" docker
  fi
  usermod -aG docker jenkins
fi

exec gosu jenkins "$@"
