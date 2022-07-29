#!/bin/bash

./build.sh -e cpu_axi_diff -c
cp -r projects/cpu_axi_diff/vsrc/ projects/cpu_axi_diff/build
if [ $1 = "-b" ]; then
    bash build.sh -e cpu_axi_diff -b -r "-i non-output/cpu-tests" -m "EMU_TRACE=1"                   
else
    ./build.sh -e cpu_axi_diff -d -s -a "-i non-output/cpu-tests/$1-cpu-tests.bin --dump-wave -b 0" -m "EMU_TRACE=1 WITH_DRAMSIM3=1" -b
    #bash build.sh -e cpu_axi_diff -d -b -s -a "-i non-output/cpu-tests/$1-cpu-tests.bin --dump-wave -b 0" -m "EMU_TRACE=1 WITH_DRAMSIM3=1" -w
fi

#use batch model: bash update.sh -b
#use particular model: bash update.sh add 
