#!/bin/bash

./build.sh -e cpu_axi_diff -c
cp -r projects/cpu_axi_diff/vsrc/ projects/cpu_axi_diff/build
if [ $1 = "-b" ]; then
    #./build.sh -e cpu_axi_diff -d -s -a "-i non-output/coremark/coremark.bin" -m "EMU_TRACE=1 WITH_DRAMSIM3=1" -b #coremark 
    bash build.sh -e cpu_axi_diff -b -r "-i non-output/cpu-tests" -m "EMU_TRACE=1 WITH_DRAMSIM3=1"                      #cpu-tests / riscv-tests
    #./build.sh -e cpu_axi_diff -d -s -a "-i custom-output/rt-thread/rtthread.bin --dump-wave -b 580000" -m "EMU_TRACE=1 WITH_DRAMSIM3=1" -b  #rtthread
elif [ $1 = "rtthread" ]; then
    ./build.sh -e cpu_axi_diff -d -s -a "-i custom-output/rt-thread/rtthread.bin --dump-wave -b 0" -m "EMU_TRACE=1 WITH_DRAMSIM3=1" -b  #rtthread
elif [ $1 = "interrupt" ]; then
    ./build.sh -e cpu_axi_diff -d -s -a "-i custom-output/interrupt-test/amtest-interrupt-test.bin " -m "EMU_TRACE=1 WITH_DRAMSIM3=1" -b -b  #--dump-wave -b 2260000
elif [ $1 = "yield" ]; then
    ./build.sh -e cpu_axi_diff -d -s -a "-i custom-output/yield-test/amtest-yield-test.bin " -m "EMU_TRACE=1 WITH_DRAMSIM3=1" -b -b  #--dump-wave -b 2260000
else                                                                                            
#time
    #./build.sh -e cpu_axi_diff -d -s -a "-i non-output/cpu-tests/$1-cpu-tests.bin --dump-wave -b 0 " -m "EMU_TRACE=1 WITH_DRAMSIM3=1" -b -b  #--dump-wave -b 2260000
#cpu-tests
    #./build.sh -e cpu_axi_diff -d -s -a "-i non-output/riscv-tests/$1-riscv-tests.bin --dump-wave -b 0" -m "EMU_TRACE=1 WITH_DRAMSIM3=1" -b -b
    ./build.sh -e cpu_axi_diff -d -s -a "-i custom-output/interrupt-test/$1-interrupt-test.bin " -m "EMU_TRACE=1 WITH_DRAMSIM3=1" -b -b  #--dump-wave -b 2260000
fi
#use batch model: bash update.sh -b
#use particular model: bash update.sh adda
