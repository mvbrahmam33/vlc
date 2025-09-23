# Windows build quickstart (cross-compile)

This repo includes small helpers to build VLC for Windows on Linux/WSL, aligned with the official doc: `doc/BUILD-win32.md`.

## Prereqs
- UNIX shell (WSL or Linux). On Windows you can use WSL or msys2.
- Toolchain: mingw-w64 with gcc, or llvm-mingw (clang). See the doc for install instructions.
- System packages similar to the VLC CI Docker image (see BUILD-win32.md).

## Use prebuilt contribs (faster)
If your toolchain matches, you can reuse prebuilt contribs to speed up builds greatly.

- gcc example (prebuilt):
  - VS Code task: "Win64: build (gcc + prebuilt)"
- llvm example (prebuilt + PDB):
  - VS Code task: "Win64: build (llvm + prebuilt)"

## CLI usage
- Configure toolchain (one time per shell):
  - GCC in PATH:
    - `source scripts/win/toolchain-setup.sh --gcc`
  - LLVM (provide bin dir):
    - `source scripts/win/toolchain-setup.sh --llvm /opt/llvm-mingw/bin`
- Build with wrapper (uses extras/package/win32/build.sh under the hood):
  - `scripts/win/build-win64.sh --gcc --use-prebuilt -a x86_64 -j 8`
  - LibVLC only: add `-z`
  - Generate PDB (LLVM): add `-d` and consider mapping paths (see doc)

## Packaging for desktop debug
- From the repo root after a build: `cd win64 && make package-win-common`
- Then run from the produced `vlc-4.0.0-dev` layout on Windows.

For all details (flags, contrib selection, debugging), see `doc/BUILD-win32.md`.