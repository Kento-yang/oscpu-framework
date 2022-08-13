//1.定时器中断/ECALL时，触发例外，进行保护寄存器到csr寄存器堆操作
//
`include "rvseed_defines.sv"
module iru (
  // wbu:
  input   logic                    wb_valid   ,
  input   logic                    wb_ready   ,
  //input   logic                    wbu_nop     ,
  input   logic [`INST_WIDTH-1:0]  wb_inst     ,
  input   logic [`DATA_WIDTH-1:0]  wb_pc      ,

  // for bru:
  output  logic                    o_iru_excp   ,//ecall/mret
  output  logic                    o_iru_intr   ,//timer
  output  logic [`DATA_WIDTH-1:0]  o_iru_pc     ,
  output  logic                    mret,
  // from csr_file:
  input   logic [`DATA_WIDTH-1:0]  mie          ,
  input   logic [`DATA_WIDTH-1:0]  mip          ,
  input   logic [`DATA_WIDTH-1:0]  mtvec        ,  // ecall.
  input   logic [`DATA_WIDTH-1:0]  mepc         ,  // mret.
  input   logic [`DATA_WIDTH-1:0]  mstatus      ,  // ecall.

  //preserve the scene
  output  logic                    o_mepc_wen     ,  // ecall.
  output  logic [`PC_WIDTH-1:0]    o_mepc_wdata   ,  // ecall.
  output  logic                    o_mcause_wen   ,  // ecall.
  output  logic [`DATA_WIDTH-1:0]  o_mcause_wdata ,  // ecall.
  output  logic                    o_mstatus_wen  ,  // ecall.
  output  logic [`DATA_WIDTH-1:0]  o_mstatus_wdata   // ecall.mret
);

  wire ecall = (wb_inst == `INST_WIDTH'h00000073);
  assign mret  = (wb_inst == `INST_WIDTH'h30200073);
  wire wbu_nop =  (wb_inst == `INST_WIDTH'h13);
  // wb_valid & (!wbu_nop) is used for waitting next correct pc!

  wire timer = wb_valid & (!wbu_nop) & mstatus[3] & mip[7] & mie[7]; // timer irq pending.

  assign o_iru_excp = ecall | mret;  // exception.
  assign o_iru_intr = timer;         // interrupt.

  //ecall/timer: expt trigger,jump to mtvec.
  //mret:        expt return, next_pc = mepc.
  assign o_iru_pc = (ecall | timer) ? mtvec : (mret ? mepc : `DATA_WIDTH'b0);
//------------------------------------------------------------------------------
//  CSR REGs protect(mstatus/mepc/mcause)
//------------------------------------------------------------------------------
  //1. mepc keep the PC before expt/intr trigger.
  assign o_mepc_wen = wb_ready & (timer | ecall);
  assign o_mepc_wdata = wb_pc;
  //2. mcause keep the reason: 
    //2.1 intr: now support timer
    //2.2 expt: now support ecall(M-mode)
  assign o_mcause_wen = wb_ready & (timer | ecall);
  assign o_mcause_wdata = timer ? `IRQ_TIMER : (ecall ? `IRQ_ECALL : `DATA_WIDTH'b0);
  //3. mstatus keep track the states of cpu. 
  assign o_mstatus_wen = wb_ready & (o_iru_excp | o_iru_intr);//ecall/timer/mret
    //3.1 ecall matstus
  logic [`DATA_WIDTH-1:0] ecall_intr_mstatus_wdata;
  assign ecall_intr_mstatus_wdata[63:13]          = mstatus[63:13];
  assign ecall_intr_mstatus_wdata[12:11]          = 2'b11; 
  assign ecall_intr_mstatus_wdata[10:8]           = mstatus[10:8];
  assign ecall_intr_mstatus_wdata[7]              = mstatus[3]; 
  assign ecall_intr_mstatus_wdata[6:4]            = mstatus[6:4]; 
  assign ecall_intr_mstatus_wdata[3]              = 1'b0;//enter M-mode,MIE = 0
  assign ecall_intr_mstatus_wdata[2:0]            = mstatus[2:0]; 
    //3.2 mret matstus
  logic [`DATA_WIDTH-1:0] mret_mstatus_wdata;
  assign mret_mstatus_wdata[63:13]                = mstatus[63:13];
  assign mret_mstatus_wdata[12:11]                = 2'b00; 
  assign mret_mstatus_wdata[10:8]                 = mstatus[10:8];
  assign mret_mstatus_wdata[7]                    = 1'b1; 
  assign mret_mstatus_wdata[6:4]                  = mstatus[6:4]; 
  assign mret_mstatus_wdata[3]                    = mstatus[7];//MIE = MPIE
  assign mret_mstatus_wdata[2:0]                  = mstatus[2:0]; 

  assign o_mstatus_wdata =  o_iru_intr | ecall  ? ecall_intr_mstatus_wdata :
                            (  mret    ? mret_mstatus_wdata  : `DATA_WIDTH'b0);

endmodule
