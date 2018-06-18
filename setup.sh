#!/bin/bash

set -euo pipefail

trap 'echo setup script failed at line $LINENO' ERR

PWD="$(pwd)"

if [ ! -d $PWD/"nim" ]; then
  git clone -b devel https://github.com/nim-lang/Nim.git nim
  pushd nim
  git clone --depth 1 https://github.com/nim-lang/csources.git
  pushd csources
  sh build.sh
  popd
  bin/nim c koch
  ./koch boot -d:release
  ./koch tools
else
  pushd nim
  git fetch origin
  if ! git merge FETCH_HEAD | grep "Already up-to-date"; then
    bin/nim c koch
    ./koch boot -d:release
  fi
fi
popd