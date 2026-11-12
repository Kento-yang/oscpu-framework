#!/bin/bash
# Source this file before building/running the difftest flow with the local (non-root) toolchain.
export CPLUS_INCLUDE_PATH=$HOME/tools/nemu-deps/usr/include:$HOME/tools/nemu-deps/usr/include/x86_64-linux-gnu
export LIBRARY_PATH=$HOME/tools/nemu-deps/usr/lib/x86_64-linux-gnu
export LD_LIBRARY_PATH=$HOME/tools/nemu-deps/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
