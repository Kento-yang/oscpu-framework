# oscpu-framework

这是一个基于`verilator`的`RISC-V`CPU开发仿真框架。  

开发前请在`myinfo.txt`文件中填写报名`一生一芯`时的学号和自己的姓名。例如：

```
ID=202100001
Name=张三
```

# 开发环境

操作系统：[Linux Ubuntu v20.04](https://ubuntu.com/download/desktop)  

开发软件：[verilator](https://verilator.org/guide/latest/)、[gtkwave](http://gtkwave.sourceforge.net/)、[mill](https://github.com/com-lihaoyi/mil)

可以使用下面的命令一键安装搭建开发环境。

```shell
# 选择使用verilog语言开发
wget https://gitee.com/oscpu/oscpu-env-setup/raw/master/oscpu-env-setup.sh && chmod +x oscpu-env-setup.sh && ./oscpu-env-setup.sh -g && rm oscpu-env-setup.sh
# 选择使用chisel语言开发
wget https://gitee.com/oscpu/oscpu-env-setup/raw/master/oscpu-env-setup.sh && chmod +x oscpu-env-setup.sh && ./oscpu-env-setup.sh -g -c && rm oscpu-env-setup.sh
```

# 获取代码

```shell
# 从gitee上克隆代码
git clone --recursive -b 2021 https://gitee.com/oscpu/oscpu-framework.git oscpu
# 从github上克隆代码
git clone --recursive -b 2021 https://github.com/OSCPU/oscpu-framework.git oscpu
```

如果子仓库克隆失败，可在`oscpu`目录下使用下面的命令重新克隆子仓库。

```shell
git submodule update --init --recursive
```

参与`一生一芯`还需要设置git信息。

```shell
# 使用你的编号和姓名拼音代替双引号中内容
git config --global user.name "4021110045-Miao Heng"
# 使用你的邮箱代替双引号中内容
git config --global user.email "1098011272@qq.com"
```

# 例程

`projects`目录用于存放工程文件夹，`projects`目录下的几个例程可用于了解如何基于`verilator`和`香山difftest框架`来开发仿真CPU。你可以在该目录下创建自己的工程。工程目录结构如下：

```shell
.
├── build.sc		# 存放chisel编译信息的文件，选择chisel语言时需要该文件
├── csrc			# 存放仿真c++源码的文件夹，接入香山difftest框架时不需要该文件夹
├── src				# 存放chisel源码的文件夹，选择chisel语言时需要该文件夹
└── vsrc			# 存放verilog源码的文件夹，选择verilog语言时需要该文件夹
```

我们提供了脚本`build.sh`用于自动化编译、仿真和查看波形。下面是`build.sh`的参数说明，也可在oscpu目录下使用`./build.sh -h`命令查看帮助。

```shell
-e 指定一个例程作为工程目录，如果不指定，将使用"cpu"目录作为工程目录
-b 编译工程，编译后会在工程目录下生成"build"(difftest)或"build_test"子目录，里面存放编译后生成的文件
-t 指定verilog顶层文件名，如果不指定，将使用"top.v" 或"SimTop.v"(difftest)作为顶层文件名，该选项在接入difftest时无效
-s 运行仿真程序，即"build/emu"程序，运行时工作目录为"build"(difftest)或"build_test"子目录
-a 传入仿真程序的参数，比如：-a "1 2 3 ......"，多个参数需要使用双引号
-f 传入c++编译器的参数，比如：-f "-DGLOBAL_DEFINE=1 -ggdb3"，多个参数需要使用双引号，该选项在接入difftest时无效
-l 传入c++链接器的参数，比如：-l "-ldl -lm"，多个参数需要使用双引号，该选项在接入difftest时无效
-g 使用gdb调试仿真程序，该选项在接入difftest时无效
-w 使用gtkwave打开工作目录下修改时间最新的.vcd波形文件
-c 删除工程目录下编译生成的"build"文件夹
-d 接入香山difftest框架
-m 传入difftest框架makefile的参数，比如：-m "EMU_TRACE=1 EMU_THREADS=4"，多个参数需要使用双引号
-r 使用给定的测试用例集合进行回归测试，比如：-r "case1 case2"，该选项要求工程能够接入difftest
```

## 编译和仿真 

### counter

`examples/counter`目录下存放了4位计数器的例程源码。可以使用下面的命令编译和仿真。

```shell
./build.sh -e counter -b -s
```

如果`verilator`安装正确，你会看到下面的输出

```shell
Simulating...
Enabling waves ...
Enter the test cycle:
```

输入测试周期数后仿真程序退出，并在`projects/counter/build_test/`路径下生成`.vcd`波形文件。

### cpu

`projects/cpu`目录下存放了`verilog`版本单周期`RISC-V`CPU例程源码，源码实现了`RV64I`指令`addi`。可以使用下面的命令编译和仿真。

```shell
./build.sh -b -t rvcpu.v -s
```

输入`inst.bin`和回车后程序结束运行，并在`projects/cpu/build_test/`路径下生成`.vcd`波形文件。其中`inst.bin`为`bin`目录下的一个`RISC-V`测试程序，里面存放了3条`addi`指令。

### cpu_diff

`projects/cpu_diff`目录下存放了接入`香山difftest框架`的`verilog`版本单周期`RISC-V` CPU例程源码，源码实现了`RV64I`指令`addi`。关于`香山difftest框架`的详细介绍，可参考[讲座-Difftest 处理器验证方法介绍](https://oscpu.github.io/ysyx/events/events.html?EID=2021-07-17_Difftest)，接口说明可参考[difftest_api.md](./doc/difftest_api.md)和[chisel_difftest.md](./doc/chisel_difftest.md)。可以使用下面的命令编译和仿真。

```shell
# 编译仿真
./build.sh -e cpu_diff -d -b -s -a "-i inst_diff.bin"
# 编译仿真，并从CPU上报至difftest的时钟周期0开始输出波形
./build.sh -e cpu_diff -d -b -s -a "-i inst_diff.bin --dump-wave -b 0" -m "EMU_TRACE=1"
```

仿真程序运行后，终端将打印绿色的提示内容`HIT GOOD TRAP at pc = 0x8000000c`。说明程序运行到自定义的`0x6b`指令，并且此时存放错误码的`a0`寄存器的值为0，即程序按照预期结果成功退出。关于`0x6b`自定义指令作用，可参考[讲座-AM运行环境介绍](https://oscpu.github.io/ysyx/events/events.html?EID=2021-07-13_AM_Difftest)。如果指定输出波形，将在`projects/cpu_diff/build/`路径下生成`.vcd`波形文件。

### cpu_axi_diff

`projects/cpu_diff`目录下存放了通过`AXI总线`接入`香山difftest框架`的`verilog`版本单周期`RISC-V`CPU例程源码，源码实现了`RV64I`指令`addi`和`AXI总线`读逻辑。可以使用下面的命令编译和仿真。

```shell
./build.sh -e cpu_axi_diff -d -s -a "-i inst_diff.bin --dump-wave -b 0" -m "EMU_TRACE=1 WITH_DRAMSIM3=1" -b
```

### chisel_cpu_diff

`projects/cpu_diff`目录下存放了接入`香山difftest框架`的`chisel`版本单周期`RISC-V` CPU例程源码，源码实现了`RV64I`指令`addi`。可以使用下面的命令编译和仿真。

```shell
./build.sh -e chisel_cpu_diff -d -s -a "-i inst_diff.bin" -m "EMU_TRACE=1" -b
```

### soc

`projects/soc`目录下存放了接入`ysyxSoC`的示例程序。源码中只有一个占位符，能够通过编译但不能正常运行。

要使用该框架，需要先按照 [ysyx SoC 的 readme](https://github.com/osCPU/ysyxsoc) 完成 `命名规范` 和 `CPU 内部修改` 两个步骤，得到 `ysyx_21xxxx.v`，随后放入 `projects/soc/vsrc/` 中。此后，执行下面的命令将会根据 `myinfo.txt` 中的 ID 自动 对代码进行规范检查、集成到 `soc` 并运行指定的程序。`ysyxSoC` 中附带的例程会被自动软连接至 `build` 目录下，仿真时可以快速使用。

```bash
./build.sh -e soc -b -s -y -v '--timescale "1ns/1ns" -Wno-fatal --trace' -a "-i ysyxSoC/flash/hello-flash.bin --dump-wave"
```

由于无法直接使用 `difftest` 框架，暂时只支持少量参数。
```bash
$ ./emu -h
Usage: ./emu [OPTION...]

  -i, --image=FILE           run with this image file
      --dump-wave            dump waveform when log is enabled
  -b, --log-begin=NUM        display log from NUM th cycle
  -e, --log-end=NUM          stop display log at NUM th cycle
  -h, --help                 print program help info
```

## 查看波形

在`oscpu`目录下使用命令可以通过`gtkwave`查看输出的波形，其中`xxx`表示例程名。

```shell
# 未接入difftest
./build.sh -e xxx -w
# 接入difftest
./build.sh -e xxx -d -w
```

# 测试用例

`bin`目录下存放了`一生一芯`[基础任务](https://oscpu.github.io/ysyx/wiki/tasks/basic.html)需要使用的测试用例，具体说明详见[一生一芯基础任务测试用例说明](./bin/README.md)。

# 回归测试

一键回归测试用于自动化测试给定的测试用例集合，可以通过以下命令对CPU进行一键回归测试。该命令会将`bin`目录下指定子目录中所有`.bin`文件作为参数来调用接入了`香山difftest框架`的仿真程序，其中`xxx`表示例程名。

```shell
# 未接入AXI总线的情况下使用"non-output/cpu-tests"和"non-output/riscv-tests"目录下的bin进行回归测试
./build.sh -e xxx -b -r "non-output/cpu-tests non-output/riscv-tests"
# 接入AXI总线的情况下使用"non-output/cpu-tests"和"non-output/riscv-tests"目录下的bin进行回归测试
./build.sh -e xxx -b -r "non-output/cpu-tests non-output/riscv-tests" -m "WITH_DRAMSIM3=1"
```

通过测试的用例，将打印`PASS`。测试失败的用例，打印`FAIL`并生成对应的log文件，可以查看log文件来调试，也可以另外开启波形输出来调试。

# 程序上传

在本框架中接入`ysyxSoC` 并完成所有测试后，可以开始代码上传流程。**上传前请确保所有触发器可复位。**

1. 创建自己的开源`git仓库`，不局限于`github`。
2. 在`oscpu`目录下创建名为`submit`的子目录。
3. 将`Verilator中Warning无法清理说明.xlsx`文件放置于`submit`目录下。
4. 制作一份带数据流向的处理器架构图，并对图中各模块做简单说明，整理成`ysyx_21xxxx.pdf`文件并放置于`submit`目录下。
5. 进入`oscpu`目录下，运行`./submit.sh`，根据提示完成代码上传操作。
6. 将自己仓库的`URL`发送给组内助教。

# 扩展

[一生一芯官网](https://oscpu.github.io/ysyx/)

[会议汇总](https://oscpu.github.io/ysyx/events/)

[讲座回放](https://www.bilibili.com/video/BV1PU4y1V7X3)

[RISC-V Unprivileged Spec](https://github.com/riscv/riscv-isa-manual/releases/download/Ratified-IMAFDQC/riscv-spec-20191213.pdf)

[RISC-V Privileged Spec](https://github.com/riscv/riscv-isa-manual/releases/download/Ratified-IMFDQC-and-Priv-v1.11/riscv-privileged-20190608.pdf)

[cpu-tests](https://github.com/NJU-ProjectN/am-kernels)

[riscv-tests](https://github.com/NJU-ProjectN/riscv-tests)

[香山difftest框架](https://github.com/OpenXiangShan/difftest)

[NEMU](https://github.com/OpenXiangShan/NEMU)

[DRAMsim3](https://github.com/OpenXiangShan/DRAMsim3)

[AXI4 specification](http://www.gstitt.ece.ufl.edu/courses/fall15/eel4720_5721/labs/refs/AXI4_specification.pdf)

# 复现记录：用带 i-cache/d-cache 的设计跑通 RV 基础用例

本节记录 2026-11-12 在本仓库复现「带 i-cache / d-cache 的 CPU 设计」并通过一生一芯基础用例的完整步骤与原因，便于重复验证。

## 复现结论

| 设计版本 | cpu-tests (33) | riscv-tests (50) | 合计 |
| --- | --- | --- | --- |
| `master` 中 `projects/cpu_axi_diff/vsrc`（无 cache） | 26 / 33 | 50 / 50 | 76 / 83 |
| `origin/CPUwithCache` @ `3cb21fd`（带 i/dcache，本次使用） | 33 / 33 | 50 / 50 | **83 / 83 PASS** |

两次完整回归均为 83 PASS / 0 FAIL，单次耗时约 59 秒。

版本选择原因：

- `master` HEAD（`a8206b1`，提交信息为 “pass dummy!”）的 7 个失败用例为 `bit`、`mov-c`、`movsx`、`string`、`hello-str`、`recursion`、`quick-sort`。失败表现为 difftest 提交 PC/指令流错位，属于该版本 RTL 的提交时序问题；同一环境下带 cache 的 `3cb21fd` 全部通过，可排除框架或环境因素。
- `origin/CPUwithCache` 最新提交 `887e8ba` 的 `dcache.sv` 残留合并冲突标记（`<<<<<<<`），无法编译；`ace67a5`（中断修复）实测为 77/83，分支/跳转类用例失败。最终选用提交信息为 “add i/dcache and pass cpu/riscv tests”、实测 83/83 的 `3cb21fd`。
- 该版本尚未实现 `0x7b` 自定义打印指令，因此 `bin/custom-output` 用例不在本次复现范围内。

## 设计源码

`projects/cpu_axi_diff_cache/vsrc/` 是 `origin/CPUwithCache` 提交 `3cb21fd` 的 `projects/cpu_axi_diff/vsrc` 快照，其中 [top_axirw.sv](projects/cpu_axi_diff_cache/vsrc/top_axirw.sv) 实例化了 `icache u_icache` 与 `dcache u_dcache`，即本次测试的是带 i-cache/d-cache 的版本。

该目录可从分支重新生成：

```bash
git archive 3cb21fd projects/cpu_axi_diff/vsrc | tar -x -C /tmp
rm -rf projects/cpu_axi_diff_cache/vsrc
cp -r /tmp/projects/cpu_axi_diff/vsrc projects/cpu_axi_diff_cache/vsrc
# 当前锁定的 difftest 版本中 DifftestInstrCommit 没有 special 端口
sed -i '/\.special[[:space:]]*(/d' projects/cpu_axi_diff_cache/vsrc/top.sv
```

## 环境准备

本次环境为 WSL2 / Ubuntu 22.04 / gcc 11.4。由于 `sudo` 需要密码，所有工具均解包到用户目录 `~/tools`，不修改系统环境。

| 工具 | 版本 | 用途 / 原因 |
| --- | --- | --- |
| Verilator | 4.204 | 框架指定版本；Ubuntu 自带的 4.038 对 `alu.sv` 的拼接位选 `{...}[63:0]` 报 `Unsupported: Select of concatenation` |
| bison / flex / m4 | 3.8.2 / 2.6.4 / 1.4.18 | NEMU 的 kconfig 构建 |
| readline | 8.1 | NEMU `src/monitor/ui.c` |
| zlib / SDL2（含运行时依赖） | 1.2.11 / 2.0.20 | difftest 的 `compress.cpp`、`device.cpp`、`vga.cpp` 及 `-lSDL2` 链接 |
| CMake | 3.22.6 | 编译 DRAMsim3 |

关键安装命令（以 Verilator 为例）：

```bash
wget -O /tmp/verilator_4_204_amd64.deb \
  https://gitee.com/oscpu/oscpu-env-setup/attach_files/817254/download/verilator_4_204_amd64.deb
dpkg -x /tmp/verilator_4_204_amd64.deb ~/tools/verilator-4.204
ln -s ~/tools/verilator-4.204/usr/bin ~/tools/verilator-4.204/usr/share/verilator/bin
ln -s ~/tools/verilator-4.204/usr/bin/verilator_bin ~/tools/verilator-4.204/usr/share/verilator/verilator_bin
```

`~/.local/bin/verilator` 需要指定 `VERILATOR_ROOT`（deb 解包后没有安装到 `/usr`）：

```bash
#!/bin/bash
export VERILATOR_ROOT=$HOME/tools/verilator-4.204/usr/share/verilator
export LD_LIBRARY_PATH=$HOME/tools/nemu-deps/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
exec $HOME/tools/verilator-4.204/usr/bin/verilator "$@"
```

其余 deb 均用 `apt-get download` 下载后 `dpkg -x` 解包到 `~/tools/nemu-deps`，包括：
`libfl2 bison flex m4 libfl-dev libreadline-dev libreadline8 libtinfo-dev libtinfo6 zlib1g-dev libsdl2-dev libsdl2-2.0-0 libasound2 libpulse0 libxss1 libgbm1 libdecor-0-0 libwayland-server0 libsndfile1 libasyncns0 libflac8 libvorbis0a libvorbisenc2 libopus0 libogg0`。
其中 `bison` 需要通过包装脚本指定 `BISON_PKGDATADIR` 和 `M4`；`~/.local/bin/ccache` 放一个 `exec "$@"` 空壳，避免 difftest 探测到不存在的 ccache。

每次编译/运行前导入 [env_local.sh](env_local.sh)：

```bash
source env_local.sh
```

它等价于：

```bash
export CPLUS_INCLUDE_PATH=$HOME/tools/nemu-deps/usr/include:$HOME/tools/nemu-deps/usr/include/x86_64-linux-gnu
export LIBRARY_PATH=$HOME/tools/nemu-deps/usr/lib/x86_64-linux-gnu
export LD_LIBRARY_PATH=$HOME/tools/nemu-deps/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
```

> 有 root 权限的机器可以直接 `dpkg -i` / `apt install` 对应包，步骤等价。

## 获取子模块与依赖

```bash
git submodule update --init --recursive \
    libraries/DRAMsim3 libraries/NEMU libraries/difftest
```

本次复现只需要 DRAMsim3、NEMU、difftest；`ysyxSoC` 是 SoC 流程使用的，`cpu_axi_diff` 不依赖它。

编译 NEMU（difftest 的参考模型）：

```bash
cd libraries/NEMU
export NEMU_HOME=$PWD
make riscv64-ysyx-ref_defconfig
make -j$(nproc)
# 生成 build/riscv64-nemu-interpreter-so，emu 运行时通过 NEMU_HOME 查找
```

编译 DRAMsim3（AXI 访存的存储器模型）：

```bash
cd libraries/DRAMsim3
mkdir -p build && cd build
cmake -D COSIM=1 ..
make -j$(nproc)
# 生成 build/libdramsim3.a，WITH_DRAMSIM3=1 时链接进 emu
```

## 框架适配改动

### 1. `build.sh`：支持 SystemVerilog 顶层

原因：difftest 的 Makefile 固定要求 `build/SimTop.v`，而本设计顶层是 `SimTop.sv`；原脚本只把 `*.v` 软链到 build 目录。改动后所有 `*.v` / `*.sv` 都进入 build 目录，并把 `SimTop.sv` 额外链接为 `SimTop.v`：

```diff
-    create_soft_link $BUILD_PATH $PROJECT_PATH/$VSRC_FOLDER \"*.v\"
+    mkdir -p $BUILD_PATH
+    find -L $BUILD_PATH -maxdepth 1 -type l -delete
+    for FILE in $(find $PROJECT_PATH/$VSRC_FOLDER -type f \( -name "*.v" -o -name "*.sv" \)); do
+        ln -sf "$FILE" "$BUILD_PATH/${FILE##*/}" 1>/dev/null 2>&1
+    done
+    if [[ -f $BUILD_PATH/SimTop.sv ]] && [[ ! -e $BUILD_PATH/SimTop.v ]]; then
+        ln -s SimTop.sv $BUILD_PATH/SimTop.v
+    fi
+    touch -m $BUILD_PATH/SimTop.v 1>/dev/null 2>&1
```

### 2. `libraries/difftest/verilator.mk`：本地库搜索路径

原因：SDL2 及其依赖解包在 `~/tools/nemu-deps`，不在系统默认库路径。`ld` 不会通过 `LIBRARY_PATH` 解析共享库的间接依赖，需要 `-rpath-link`；同时写入 `-rpath` 方便运行：

```diff
+ifneq ($(LOCAL_LIB_PATH),)
+EMU_LDFLAGS += -Wl,-rpath-link,$(LOCAL_LIB_PATH) -Wl,-rpath,$(LOCAL_LIB_PATH)
+endif
```

### 3. `.no_commit`：关闭编译后的自动提交

`build.sh` 在编译后会以 `tracer-oscpu2021` 身份自动执行 `git commit`。在仓库根目录创建空文件 `.no_commit` 可关闭该行为，避免复现过程产生无关提交。

## 编译

```bash
cd ~/oscpu-framework
source env_local.sh
./build.sh -e cpu_axi_diff_cache -d -b \
  -m "WITH_DRAMSIM3=1 LOCAL_LIB_PATH=$HOME/tools/nemu-deps/usr/lib/x86_64-linux-gnu"
```

成功后在 `projects/cpu_axi_diff_cache/build/emu` 生成仿真器。

## 回归测试

```bash
./build.sh -e cpu_axi_diff_cache -b \
  -r "non-output/cpu-tests non-output/riscv-tests" \
  -m "WITH_DRAMSIM3=1 LOCAL_LIB_PATH=$HOME/tools/nemu-deps/usr/lib/x86_64-linux-gnu"
```

预期输出（每个用例一行 PASS）：

```
PASS = 83, FAIL = 0      # 33 个 cpu-tests + 50 个 riscv-tests
```

单条用例运行：

```bash
cd projects/cpu_axi_diff_cache/build
NEMU_HOME=~/oscpu-framework/libraries/NEMU \
LD_LIBRARY_PATH=$HOME/tools/nemu-deps/usr/lib/x86_64-linux-gnu \
./emu -i non-output/cpu-tests/dummy-cpu-tests.bin
```

输出示例：

```
Using .../libraries/NEMU/build/riscv64-nemu-interpreter-so for difftest
The first instruction of core 0 has commited. Difftest enabled.
Core 0: HIT GOOD TRAP at pc = 0x8000004c
total guest instructions = 420
```

## 注意事项

1. 回归脚本以日志中出现 `HIT GOOD TRAP` 作为通过标准；失败用例的日志在 `projects/cpu_axi_diff_cache/build/log/`。
2. `LD_LIBRARY_PATH` 必须包含 `~/tools/nemu-deps/usr/lib/x86_64-linux-gnu`：emu 的 `RUNPATH` 只覆盖直接依赖（libSDL2），SDL2 的间接依赖（libasound 等）仍依赖该环境变量。
3. `-r` 会把 `bin/` 下的目录软链到 `build/`，因此单测路径是 `non-output/cpu-tests/xxx.bin`，不是 `cpu-tests/xxx.bin`。
4. 若使用其他 Verilator 版本遇到 `Unsupported: Select of concatenation`，请切换到 4.204。
