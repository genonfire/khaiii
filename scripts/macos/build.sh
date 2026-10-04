#!/bin/bash
# Build libkhaiii.dylib + base-model resources from the checked-out sources.
# usage: build.sh <repo-root> <build-dir>
set -euo pipefail
SRC="$(cd "$1" && pwd)"; BUILD="$2"
rm -rf "$BUILD"; mkdir -p "$BUILD"; BUILD="$(cd "$BUILD" && pwd)"
cd "$BUILD"
# FMA=OFF: -mfma is x86-only. Pin the target explicitly so nothing can drift to x86_64.
cmake -DFMA=OFF -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
      "$SRC" 2>&1 | tee cmake-configure.log
make -j"$(sysctl -n hw.ncpu)" khaiii 2>&1 | tee make-khaiii.log
make PREFIX="$BUILD" -C "$SRC/rsc" 2>&1 | tee make-resource.log   # base model, share/khaiii
ls -l "$BUILD/lib" "$BUILD/share/khaiii"
