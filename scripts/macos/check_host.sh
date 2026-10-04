#!/bin/bash
# Log host/toolchain info and fail closed unless the host is macOS (Darwin) arm64.
set -euo pipefail
echo "runner label : ${RUNNER_LABEL:-unknown} (RUNNER_OS=${RUNNER_OS:-?} RUNNER_ARCH=${RUNNER_ARCH:-?})"
echo "uname -s     : $(uname -s)"
echo "uname -m     : $(uname -m)"
echo "cpu brand    : $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo n/a)"
echo "sw_vers      : $(sw_vers -productVersion 2>/dev/null || echo n/a)"
echo "proc_translated: $(sysctl -n sysctl.proc_translated 2>/dev/null || echo n/a)"
echo "xcode        : $(xcodebuild -version 2>/dev/null | tr '\n' ' ' || echo n/a)"
echo "clang        : $(clang --version | head -1)"
echo "cmake        : $(cmake --version | head -1)"
echo "python       : $(python3 --version)"
echo "make         : $(make --version | head -1)"
[ "$(uname -s)" = "Darwin" ] || { echo "FATAL: not Darwin" >&2; exit 1; }
[ "$(uname -m)" = "arm64" ]  || { echo "FATAL: not arm64 (Rosetta/x86_64?)" >&2; exit 1; }
[ "$(sysctl -n sysctl.proc_translated 2>/dev/null || echo 0)" != "1" ] \
    || { echo "FATAL: running under Rosetta translation" >&2; exit 1; }
echo "host check OK: Darwin/arm64"
