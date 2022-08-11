`include "rvseed_defines.sv"

// core local interruptor module
// 核心中断管理、仲裁模块
/*
CLINT 模块：中断控制模块，负责配置中断/异常相关的CSR、产生中断跳转、读写CLINT
寄存器。CLINT 采集送入IDU 的pc 和指令，并且检查是否为异常指令、异常返回指令，如
果是则配置CSR 寄存器，然后产生中断（异常）信号到EXU 模块，由EXU 产生跳转信号给
IFU。对于中断，则需要判断送入的指令是否执行完成，需要统一等到该指令执行完后再产
生中断。
*/
module clint (
  input logic                   clk         ,
  input logic                   rst_n       ,

  // from cpu lsu:
  input  logic                   clint_ren   ,
  input  logic [`DATA_WIDTH-1:0] clint_raddr ,

  output logic [`DATA_WIDTH-1:0] clint_rdata ,

  input  logic                   clint_wen   ,
  input  logic [`DATA_WIDTH-1:0] clint_waddr ,
  input  logic [`DATA_WIDTH-1:0] clint_wdata ,
  
  // to csr_file:
  output logic                  o_clint_mtip
);

  reg [`DATA_WIDTH-1:0]     mtime, mtimecmp; // for both 32bit/64bit arch.

  // read:
  wire ren_mtimecmp, ren_mtime;
  assign ren_mtimecmp = clint_ren & (clint_raddr == `MTIMECMP_ADDR);
  assign ren_mtime    = clint_ren & (clint_raddr == `MTIME_ADDR   );

  assign clint_rdata = ren_mtime ? mtime : (ren_mtimecmp ? mtimecmp : `DATA_WIDTH'b0);

  // write:
  wire lsu_wen_mtime, cnt_wen_mtime, wen_mtimecmp, wen_mtime;

  wire [`DATA_WIDTH-1:0] wdata_mtimecmp, wdata_mtime;

  assign lsu_wen_mtime  = clint_wen & (clint_waddr == `MTIME_ADDR);
  assign cnt_wen_mtime  = !o_clint_mtip;

  assign wen_mtime      = lsu_wen_mtime | cnt_wen_mtime;
  assign wdata_mtime    = lsu_wen_mtime ? clint_wdata : (mtime + 1);
  Reg #(
    .WIDTH     (`DATA_WIDTH    ),
    .RESET_VAL (`DATA_WIDTH'b0 )
  ) reg_mtime (
    .clk     (clk           ),
    .rst_n   (rst_n         ),
    .wen     (wen_mtime     ),
    .din     (wdata_mtime   ),
    .dout    (mtime         )
  );

  assign wen_mtimecmp   = clint_wen & (clint_waddr == `MTIMECMP_ADDR);
  assign wdata_mtimecmp = clint_wdata;
  Reg #(
    .WIDTH     (`DATA_WIDTH    ),
    .RESET_VAL (`DATA_WIDTH'b0 )
  ) reg_mtimcmp (
    .clk     (clk           ),
    .rst_n   (rst_n         ),
    .wen     (wen_mtimecmp  ),
    .din     (wdata_mtimecmp),
    .dout    (mtimecmp      )
  );

  assign o_clint_mtip = (mtime >= mtimecmp);

endmodule