#!/bin/bash                                                                                                            
   
cp projects/cpu_axi_diff/vsrc/*.sv projects/cpu_axi_diff/build/
bash build.sh -e cpu_diff -d -b -s -a "-i non-output/cpu-tests/$1-cpu-tests.bin --dump-wave -b 0" -m "EMU_TRACE=1" -w
