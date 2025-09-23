#!/usr/bin/env bash
set -euo pipefail

# Thin wrapper around ../extras/package/win32/build.sh
# Adds convenience flags and prebuilt contribs support.

usage() {
  cat <<'USAGE'
Usage: scripts/win/build-win64.sh [-a x86_64] [-p] [-z] [-d] [-j N] [--llvm BIN_DIR|--gcc] [--use-prebuilt]

Options:
  -a arch        Target arch (default: x86_64)
  -p             Use prebuilt contribs (alias of --use-prebuilt)
  -z             Build libvlc only (skip desktop app)
  -d             Enable PDB generation (LLVM) for Windows Debugger
  -j N           Limit jobs for make (export JOBS=N). Use MESON_BUILD="-j 1" to tame meson.
  --llvm DIR     Use llvm-mingw toolchain at DIR (bin folder)
  --gcc          Use gcc mingw toolchain found in PATH
  --use-prebuilt Use prebuilt contribs matching current VLC_CONTRIB_SHA

Environment:
  CONFIGFLAGS, CONTRIBFLAGS, VLC_PREBUILT_CONTRIBS_URL are forwarded to build.sh
USAGE
}

ARCH=x86_64
JOBS=${JOBS-}
PDB=
LIBVLC_ONLY=
USE_PREBUILT=
TOOLCHAIN=
LLVM_BIN=

while (( "$#" )); do
  case "$1" in
    -a) ARCH="$2"; shift 2;;
    -p) USE_PREBUILT=1; shift;;
    --use-prebuilt) USE_PREBUILT=1; shift;;
    -z) LIBVLC_ONLY=1; shift;;
    -d) PDB=1; shift;;
    -j) JOBS="$2"; shift 2;;
    --llvm) TOOLCHAIN=llvm; LLVM_BIN="$2"; shift 2;;
    --gcc) TOOLCHAIN=gcc; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 2;;
  esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"
cd "$ROOT_DIR"

# Configure toolchain
if [[ -n "$TOOLCHAIN" ]]; then
  if [[ "$TOOLCHAIN" == "llvm" ]]; then
    # shellcheck source=/dev/null
    source scripts/win/toolchain-setup.sh --llvm "$LLVM_BIN"
  else
    # shellcheck source=/dev/null
    source scripts/win/toolchain-setup.sh --gcc
  fi
fi

# Prebuilt contribs URL
if [[ -n "$USE_PREBUILT" ]]; then
  VLC_CONTRIB_SHA="$(cd .. 2>/dev/null || true; ./extras/ci/get-contrib-sha.sh win32 || ./extras/ci/get-contrib-sha.sh win64)" || true
  if [[ -z "${VLC_CONTRIB_SHA:-}" ]]; then
    VLC_CONTRIB_SHA="$(./extras/ci/get-contrib-sha.sh win32)"
  fi
  if [[ "${TOOLCHAIN:-gcc}" == "llvm" ]]; then
    export VLC_PREBUILT_CONTRIBS_URL="https://artifacts.videolan.org/vlc/win64-llvm/vlc-contrib-x86_64-w64-mingw32-${VLC_CONTRIB_SHA}.tar.bz2"
  else
    export VLC_PREBUILT_CONTRIBS_URL="https://artifacts.videolan.org/vlc/win64/vlc-contrib-x86_64-w64-mingw32-${VLC_CONTRIB_SHA}.tar.bz2"
  fi
  export VLC_CONTRIB_SHA
fi

# Threading controls
if [[ -n "$JOBS" ]]; then export JOBS; fi
export MESON_BUILD="${MESON_BUILD-"-j 1"}"

BUILD_FLAGS=("-a" "$ARCH")
[[ -n "$PDB" ]] && BUILD_FLAGS+=("-d")
[[ -n "$LIBVLC_ONLY" ]] && BUILD_FLAGS+=("-z")

echo ">> Invoking extras/package/win32/build.sh ${BUILD_FLAGS[*]}"
exec extras/package/win32/build.sh "${BUILD_FLAGS[@]}"
