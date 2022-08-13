#!/bin/bash

./build.sh -e cpu_axi_diff -c
cp -r projects/cpu_axi_diff/vsrc/ projects/cpu_axi_diff/build
if [ $1 = "-b" ]; then
    #bash build.sh -e cpu_axi_diff -b -r "-i non-output/cpu-tests" -m "EMU_TRACE=1 WITH_DRAMSIM3=1"   --dump-wave -b 5200000
    ./build.sh -e cpu_axi_diff -d -s -a "-i custom-output/rt-thread/rtthread.bin" -m "EMU_TRACE=1 WITH_DRAMSIM3=1" -b
else 
#time
    #./build.sh -e cpu_axi_diff -d -s -a "-i custom-output/time-test/$1-time-test.bin --dump-wave -b 0" -m "EMU_TRACE=1 WITH_DRAMSIM3=1" -b
#cpu-tests
    ./build.sh -e cpu_axi_diff -d -s -a "-i non-output/cpu-tests/$1-cpu-tests.bin --dump-wave -b 0" -m "EMU_TRACE=1 WITH_DRAMSIM3=1" -b

fi

#use batch model: bash update.sh -b
#use particular model: bash update.sh add 
