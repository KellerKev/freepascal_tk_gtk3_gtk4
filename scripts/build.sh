#!/usr/bin/env bash
# Compile the demo. Separated from pixi.toml because pixi's task shell
# doesn't support multi-flag invocations cleanly.
set -euo pipefail

mkdir -p build

# -Mobjfpc     : ObjFPC language mode (classes, etc.)
# -Sh          : enable AnsiStrings
# -Fusrc/lib   : search path for our own units
# -FUbuild     : unit output dir (so .o/.ppu files don't litter src/)
# -k-L$LIB     : pass -L to linker so it finds libtcl8.6/libtk8.6
# -k-ltcl8.6   : link against tcl
# -k-ltk8.6    : link against tk
LIB="${CONDA_PREFIX:-/usr/local}/lib"
# -k-rpath,$LIB bakes the conda env's lib path into the binary so it finds
# libtcl/libtk without needing DYLD_LIBRARY_PATH at runtime.
fpc -Mobjfpc -Sh -gl \
    "-Fusrc/lib" \
    "-FUbuild" \
    "-k-L$LIB" \
    "-k-rpath" "-k$LIB" \
    "-k-ltcl8.6" "-k-ltk8.6" \
    -obuild/demo \
    src/demo.pas
