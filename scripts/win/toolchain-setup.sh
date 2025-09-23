#!/usr/bin/env bash
set -euo pipefail

# Adds llvm-mingw (or gcc mingw) toolchain to PATH for cross-compiling VLC for Windows.
# Usage: source scripts/win/toolchain-setup.sh [--llvm BIN_DIR] [--gcc]

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "This script must be sourced: 'source scripts/win/toolchain-setup.sh [--llvm dir]|[--gcc]'" >&2
  exit 1
fi

case "${1-}" in
  --llvm)
    if [[ -z "${2-}" ]]; then echo "Missing llvm-mingw bin dir path" >&2; return 2; fi
    export PATH="$2:$PATH"
    export CC=x86_64-w64-mingw32-clang
    export CXX=x86_64-w64-mingw32-clang++
    ;;
  --gcc)
    export CC=x86_64-w64-mingw32-gcc
    export CXX=x86_64-w64-mingw32-g++
    ;;
  *)
    echo "Specify --llvm <bin_dir> or --gcc" >&2
    return 2
    ;;
esac

export HOST=x86_64-w64-mingw32
echo "Toolchain configured (CC=$CC, CXX=$CXX, HOST=$HOST)"
