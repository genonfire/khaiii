#!/bin/bash
# Verify a dylib is a relocatable Mach-O arm64 library with only system deps.
# usage: verify_binary.sh <libkhaiii.dylib> [expected-install-name]
set -euo pipefail
LIB="$1"; EXPECT_ID="${2:-@rpath/libkhaiii.0.dylib}"   # raw CMake output; packaged lib uses @rpath/libkhaiii.dylib
file "$LIB" | tee /dev/stderr | grep -q "Mach-O 64-bit dynamically linked shared library arm64" \
    || { echo "FATAL: not a Mach-O arm64 dylib" >&2; exit 1; }
[ "$(lipo -archs "$LIB")" = "arm64" ] || { echo "FATAL: lipo archs != arm64" >&2; exit 1; }
echo "--- otool -D (install name)"; otool -D "$LIB"
echo "--- otool -L"; otool -L "$LIB"
echo "--- otool -l (LC_RPATH)"; otool -l "$LIB" | grep -A2 LC_RPATH || echo "no LC_RPATH"
ID="$(otool -D "$LIB" | tail -1)"
[ "$ID" = "$EXPECT_ID" ] || { echo "FATAL: unexpected install name: $ID (expected $EXPECT_ID)" >&2; exit 1; }
# Everything after the first (self) line must be a system library.
BAD="$(otool -L "$LIB" | tail -n +3 | awk '{print $1}' | grep -v -E '^(/usr/lib/libc\+\+\.1\.dylib|/usr/lib/libc\+\+abi\.dylib|/usr/lib/libSystem\.B\.dylib)$' || true)"
[ -z "$BAD" ] || { echo "FATAL: unexpected dynamic dependencies:"; echo "$BAD"; exit 1; }
if otool -l "$LIB" | grep -A2 LC_RPATH | grep -E 'path (/Users|/Applications|/opt|/usr/local|/private)' ; then
    echo "FATAL: runner-specific LC_RPATH" >&2; exit 1
fi
echo "binary verification OK"
