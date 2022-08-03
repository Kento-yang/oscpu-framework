`include "defines.sv"
module core_top(
  input                 i_clk       ,
  input                 i_rst_n     ,
  uni_if.Master         UniIf_ifu_M ,
  uni_if.Master         UniIf_lsu_M ,
  output                s_uart_out_valid,
  output [7:0]          s_uart_out_char
);

  // control signals:
  logic [`CPU_WIDTH-1:0]  pre_pc, ifu_pc, idu_pc, exu_pc, lsu_pc, wbu_pc, iru_pc;
  logic [`INS_WIDTH-1:0]  ifu_ins, idu_ins, exu_ins, lsu_ins, wbu_ins;
  logic                            idu_nop, exu_nop, lsu_nop, wbu_nop;

  logic                   clint_ren  , clint_wen  , clint_mtip ;
  logic [`CPU_WIDTH-1:0]  clint_raddr, clint_waddr, clint_rdata, clint_wdata;

  logic                   ifid_nop;               // for branch adventure
  logic                   ifid_stall, idex_nop;   // for data adventure
  logic                   idu_ldstbp, exu_ldstbp; // for ld -> st bypass.
  logic                   ifu_valid , ifu_ready;  // pipeline shakehands: pc/if -> if/id
  logic                   idu_valid , idu_ready;  // pipeline shakehands: if/id -> id/ex
  logic                   exu_valid , exu_ready;  // pipeline shakehands: id/ex -> ex/ls
  logic                   lsu_valid , lsu_ready;  // pipeline shakehands: ex/ls -> ls/wb
  logic                   wbu_valid , wbu_ready;  // pipeline shakehands: ls/wb -> wb/reg.
  logic                   iru_excp  , iru_intr;
  logic                   wbu_commit;             // wbu_valid & wbu_ready & !iru_intr.
  logic                   unif_trans_done, flush;

  assign unif_trans_done = (UniIf_ifu_M.valid & UniIf_ifu_M.ready | !UniIf_ifu_M.valid) & (UniIf_lsu_M.valid & UniIf_lsu_M.ready | !UniIf_lsu_M.valid);
  assign wbu_ready = (iru_excp | iru_intr) ? unif_trans_done: 1'b1;         // if excp/intr, waiting for unif done.
  assign flush     = (iru_excp | iru_intr) & (wbu_valid & wbu_ready);       // iru_intr not commit.

  // simulation signals:
  logic [2:0]             s_id_err ;
  logic [`CPU_WIDTH-1:0]  s_regs [`REG_COUNT-1:0];
  logic [`CPU_WIDTH-1:0]  s_mtvec, s_mepc, s_mstatus, s_mcause, s_mcycle, s_mie, s_mip;
  logic                   s_lsu_lsclint, s_wbu_lsclint;

  // 2.1 ifu ////////////////////////////////////////////////////////

  ifu u_ifu(
    .i_clk        (i_clk      ),
    .i_rst_n      (i_rst_n    ),
    .UniIf_M      (UniIf_ifu_M),
    .o_post_valid (ifu_valid  ),
    .i_post_ready (ifu_ready  ),
    .i_next_pc    (pre_pc     ),
    .o_ifu_pc     (ifu_pc     ),
    .o_ifu_ins    (ifu_ins    )
  );

  // 2.2 idu ////////////////////////////////////////////////////////

  // for bypass to get reg value.
  logic [`REG_ADDRW-1:0]      idu_rs1id,idu_rs2id;
  logic [`CSR_ADDRW-1:0]      idu_csrsid ;
  logic                       idu_csrsren;
  // get rs value from bypass: 
  logic [`CPU_WIDTH-1:0]      idu_rs1,idu_rs2;
  logic [`CPU_WIDTH-1:0]      idu_csrs;
  // for exu:
  logic                       idu_sysins;
  logic [`CPU_WIDTH-1:0]      idu_imm;
  logic [`EXU_SEL_WIDTH-1:0]  idu_exsrc;
  logic [`EXU_OPT_WIDTH-1:0]  idu_exopt;
  logic                       idu_excsrsrc;
  logic [`CSR_OPT_WIDTH-1:0]  idu_excsropt;
  // for lsu:
  logic [2:0]                 idu_lsfunc3;
  logic                       idu_lden;
  logic                       idu_sten;
  // for wbu:
  logic [`REG_ADDRW-1:0]      idu_rdid    ;
  logic                       idu_rdwen   ;
  logic [`CSR_ADDRW-1:0]      idu_csrdid  ;
  logic                       idu_csrdwen ; 

  // for bru:
  logic                       idu_jal,idu_jalr,idu_brch;
  logic [2:0]                 idu_bfun3;

  idu u_idu(
    .i_clk          (i_clk        ),
    .i_rst_n        (i_rst_n      ),
    .i_flush        (flush        ),
    .i_pre_nop      (ifid_nop     ),
    .i_pre_stall    (ifid_stall   ),
    .i_pre_valid    (ifu_valid    ),
    .o_pre_ready    (ifu_ready    ),
    .o_post_valid   (idu_valid    ),
    .i_post_ready   (idu_ready    ),
    .i_ifu_ins      (ifu_ins      ),
    .i_ifu_pc       (ifu_pc       ),
    .o_idu_rs1id    (idu_rs1id    ),
    .o_idu_rs2id    (idu_rs2id    ),
    .o_idu_csrsid   (idu_csrsid   ),
    .o_idu_csrsren  (idu_csrsren  ),
    .o_idu_sysins   (idu_sysins   ),
    .o_idu_imm      (idu_imm      ),
    .o_idu_exsrc    (idu_exsrc    ),
    .o_idu_exopt    (idu_exopt    ),
    .o_idu_excsrsrc (idu_excsrsrc ),
    .o_idu_excsropt (idu_excsropt ),
    .o_idu_lsfunc3  (idu_lsfunc3  ),
    .o_idu_lden     (idu_lden     ),
    .o_idu_sten     (idu_sten     ),
    .o_idu_rdid     (idu_rdid     ),
    .o_idu_rdwen    (idu_rdwen    ),
    .o_idu_csrdid   (idu_csrdid   ),
    .o_idu_csrdwen  (idu_csrdwen  ),
    .o_idu_jal      (idu_jal      ),
    .o_idu_jalr     (idu_jalr     ),
    .o_idu_brch     (idu_brch     ),
    .o_idu_bfun3    (idu_bfun3    ),
    .o_idu_pc       (idu_pc       ),
    .o_idu_ins      (idu_ins      ),
    .o_idu_nop      (idu_nop      ),
    .s_idu_iderr    (s_id_err     )
  );

  // 2.3 exu ///////////////////////////////////////////////

  // generate exu output value:
  logic [`CPU_WIDTH-1:0]      exu_exres;
  // bypss: 
  logic [`CPU_WIDTH-1:0]      exu_rs2;    // from exu to bypass unit.
  logic [`CPU_WIDTH-1:0]      exu_rs2_bp; // from bypss unit to lsu input for store ins.
  // for lsu:
  logic [2:0]                 exu_lsfunc3;
  logic                       exu_lden,exu_sten;
  // for wbu:
  logic [`REG_ADDRW-1:0]      exu_rdid    ;
  logic                       exu_rdwen   ;
  logic [`CSR_ADDRW-1:0]      exu_csrdid  ;
  logic                       exu_csrdwen ;
  logic [`CPU_WIDTH-1:0]      exu_csrd    ;

  exu u_exu(
    .i_clk          (i_clk          ),
    .i_rst_n        (i_rst_n        ),
    .i_flush        (flush          ),
    .i_pre_nop      (idex_nop       ),
    .i_pre_valid    (idu_valid      ),
    .o_pre_ready    (idu_ready      ),
    .o_post_valid   (exu_valid      ),
    .i_post_ready   (exu_ready      ),
    .i_idu_sysins   (idu_sysins     ),
    .i_idu_imm      (idu_imm        ),
    .i_idu_csrs     (idu_csrs       ),
    .i_idu_rs1      (idu_rs1        ),
    .i_idu_rs2      (idu_rs2        ),
    .i_idu_exsrc    (idu_exsrc      ),
    .i_idu_exopt    (idu_exopt      ),
    .i_idu_excsrsrc (idu_excsrsrc   ),
    .i_idu_excsropt (idu_excsropt   ),
    .i_idu_lsfunc3  (idu_lsfunc3    ),
    .i_idu_lden     (idu_lden       ),
    .i_idu_sten     (idu_sten       ),
    .i_idu_ldstbp   (idu_ldstbp     ),
    .i_idu_rdid     (idu_rdid       ),
    .i_idu_rdwen    (idu_rdwen      ),
    .i_idu_csrdid   (idu_csrdid     ),
    .i_idu_csrdwen  (idu_csrdwen    ),
    .i_idu_pc       (idu_pc         ),
    .i_idu_ins      (idu_ins        ),
    .i_idu_nop      (idu_nop        ),
    .o_exu_rs2      (exu_rs2        ),
    .o_exu_lsfunc3  (exu_lsfunc3    ),
    .o_exu_lden     (exu_lden       ),
    .o_exu_sten     (exu_sten       ),
    .o_exu_ldstbp   (exu_ldstbp     ),
    .o_exu_rdid     (exu_rdid       ),
    .o_exu_rdwen    (exu_rdwen      ),
    .o_exu_res      (exu_exres      ),
    .o_exu_csrdid   (exu_csrdid     ),
    .o_exu_csrdwen  (exu_csrdwen    ),
    .o_exu_csrd     (exu_csrd       ),
    .o_exu_pc       (exu_pc         ),
    .o_exu_ins      (exu_ins        ),
    .o_exu_nop      (exu_nop        )
  );

  // 2.4 lsu ///////////////////////////////////////////////

  logic [`CPU_WIDTH-1:0]      lsu_exres  ;
  logic [`CPU_WIDTH-1:0]      lsu_lsres  ;
  logic                       lsu_lden   ;
  logic [`REG_ADDRW-1:0]      lsu_rdid   ;
  logic                       lsu_rdwen  ;
  logic [`CSR_ADDRW-1:0]      lsu_csrdid ;
  logic                       lsu_csrdwen;
  logic [`CPU_WIDTH-1:0]      lsu_csrd   ;

  lsu u_lsu(
    .i_clk         (i_clk         ),
    .i_rst_n       (i_rst_n       ),
    .i_flush       (flush         ),
    .UniIf_M       (UniIf_lsu_M   ),
    .i_pre_valid   (exu_valid     ),
    .o_pre_ready   (exu_ready     ),
    .o_post_valid  (lsu_valid     ),
    .i_post_ready  (lsu_ready     ),
    .i_exu_exres   (exu_exres     ),
    .i_exu_rs2     (exu_rs2_bp    ),
    .i_exu_lsfunc3 (exu_lsfunc3   ),
    .i_exu_lden    (exu_lden      ),
    .i_exu_sten    (exu_sten      ),
    .i_exu_rdid    (exu_rdid      ),
    .i_exu_rdwen   (exu_rdwen     ),
    .i_exu_csrdid  (exu_csrdid    ),
    .i_exu_csrdwen (exu_csrdwen   ),
    .i_exu_csrd    (exu_csrd      ),
    .i_exu_pc      (exu_pc        ),
    .i_exu_ins     (exu_ins       ),
    .i_exu_nop     (exu_nop       ),
    .o_clint_ren   (clint_ren     ),
    .o_clint_raddr (clint_raddr   ),
    .i_clint_rdata (clint_rdata   ),
    .o_clint_wen   (clint_wen     ),
    .o_clint_waddr (clint_waddr   ),
    .o_clint_wdata (clint_wdata   ),
    .o_lsu_lsres   (lsu_lsres     ),
    .o_lsu_exres   (lsu_exres     ),
    .o_lsu_lden    (lsu_lden      ),
    .o_lsu_rdid    (lsu_rdid      ),
    .o_lsu_rdwen   (lsu_rdwen     ),
    .o_lsu_csrdid  (lsu_csrdid    ),
    .o_lsu_csrdwen (lsu_csrdwen   ),
    .o_lsu_csrd    (lsu_csrd      ),
    .o_lsu_pc      (lsu_pc        ),
    .o_lsu_ins     (lsu_ins       ),
    .o_lsu_nop     (lsu_nop       ),
    .s_lsu_lsclint (s_lsu_lsclint )
  );

  // 2.5 wbu ///////////////////////////////////////////////

  logic [`REG_ADDRW-1:0]      wbu_rdid   ;
  logic                       wbu_rdwen  ;
  logic [`CPU_WIDTH-1:0]      wbu_rd     ;
  logic [`CSR_ADDRW-1:0]      wbu_csrdid ;
  logic                       wbu_csrdwen;
  logic [`CPU_WIDTH-1:0]      wbu_csrd   ;

  wbu u_wbu(
    .i_clk         (i_clk        ),
    .i_rst_n       (i_rst_n      ),
    .i_flush       (flush        ),
    .i_pre_valid   (lsu_valid    ),
    .o_pre_ready   (lsu_ready    ),
    .o_post_valid  (wbu_valid    ),
    .i_post_ready  (wbu_ready    ),
    .i_lsu_exres   (lsu_exres    ),
    .i_lsu_lsres   (lsu_lsres    ),
    .i_lsu_lden    (lsu_lden     ),
    .i_lsu_rdid    (lsu_rdid     ),
    .i_lsu_rdwen   (lsu_rdwen    ),
    .i_lsu_csrdid  (lsu_csrdid   ),
    .i_lsu_csrdwen (lsu_csrdwen  ),
    .i_lsu_csrd    (lsu_csrd     ),
    .i_lsu_pc      (lsu_pc       ),
    .i_lsu_ins     (lsu_ins      ),
    .i_iru_intr    (iru_intr     ),
    .i_lsu_nop     (lsu_nop      ),
    .s_lsu_lsclint (s_lsu_lsclint),
    .o_wbu_rdid    (wbu_rdid     ),
    .o_wbu_rdwen   (wbu_rdwen    ),
    .o_wbu_rd      (wbu_rd       ),
    .o_wbu_csrdid  (wbu_csrdid   ),
    .o_wbu_csrdwen (wbu_csrdwen  ),
    .o_wbu_csrd    (wbu_csrd     ),
    .o_wbu_commit  (wbu_commit   ),
    .o_wbu_pc      (wbu_pc       ),
    .o_wbu_ins     (wbu_ins      ),
    .o_wbu_nop     (wbu_nop      ),
    .s_wbu_lsclint (s_wbu_lsclint)
  );

  logic [`CPU_WIDTH-1:0]  mie           ;
  logic [`CPU_WIDTH-1:0]  mip           ;
  logic [`CPU_WIDTH-1:0]  mtvec         ;
  logic [`CPU_WIDTH-1:0]  mepc          ;
  logic [`CPU_WIDTH-1:0]  mstatus       ;
  logic                   mepc_wen      ;
  logic [`CPU_WIDTH-1:0]  mepc_wdata    ;
  logic                   mcause_wen    ;
  logic [`CPU_WIDTH-1:0]  mcause_wdata  ;
  logic                   mstatus_wen   ;
  logic [`CPU_WIDTH-1:0]  mstatus_wdata ;

  iru u_iru(
    .i_clk           (i_clk           ),
    .i_rst_n         (i_rst_n         ),
    .i_wbu_valid     (wbu_valid       ),
    .i_wbu_ready     (wbu_ready       ),
    .i_wbu_nop       (wbu_nop         ),
    .i_wbu_ins       (wbu_ins         ),
    .i_wbu_pc        (wbu_pc          ),
    .o_iru_excp      (iru_excp        ),
    .o_iru_intr      (iru_intr        ),
    .o_iru_pc        (iru_pc          ),
    .i_mie           (mie             ),
    .i_mip           (mip             ),
    .i_mtvec         (mtvec           ),
    .i_mepc          (mepc            ),
    .i_mstatus       (mstatus         ),
    .o_mepc_wen      (mepc_wen        ),
    .o_mepc_wdata    (mepc_wdata      ),
    .o_mcause_wen    (mcause_wen      ),
    .o_mcause_wdata  (mcause_wdata    ),
    .o_mstatus_wen   (mstatus_wen     ),
    .o_mstatus_wdata (mstatus_wdata   )
  );

  clint u_clint(
    .i_clk         (i_clk         ),
    .i_rst_n       (i_rst_n       ),
    .i_clint_ren   (clint_ren     ),
    .i_clint_raddr (clint_raddr   ),
    .o_clint_rdata (clint_rdata   ),
    .i_clint_wen   (clint_wen     ),
    .i_clint_waddr (clint_waddr   ),
    .i_clint_wdata (clint_wdata   ),
    .o_clint_mtip  (clint_mtip    )
  );

  // 2.6 bypass, regfile read/write. ///////////////////////
  bypass u_bypass(
    .i_clk        (i_clk        ),
    // generate rs1,rs2:
    .i_idu_rs1id  (idu_rs1id    ),
    .i_idu_rs2id  (idu_rs2id    ),
    .i_idu_sten   (idu_sten     ),
    .i_exu_lden   (exu_lden     ),
    .i_exu_rdwen  (exu_rdwen    ),
    .i_exu_rdid   (exu_rdid     ),
    .i_exu_exres  (exu_exres    ),
    .i_lsu_lden   (lsu_lden     ),
    .i_lsu_rdwen  (lsu_rdwen    ),
    .i_lsu_rdid   (lsu_rdid     ),
    .i_lsu_exres  (lsu_exres    ),
    .i_lsu_lsres  (lsu_lsres    ),
    .i_wbu_rdwen  (wbu_rdwen    ),
    .i_wbu_rdid   (wbu_rdid     ),
    .i_wbu_rd     (wbu_rd       ),
    .o_idu_rs1    (idu_rs1      ),
    .o_idu_rs2    (idu_rs2      ),
    .o_idex_nop   (idex_nop     ),
    .o_ifid_stall (ifid_stall   ),
    // generate regst:
    .i_exu_rs2    (exu_rs2      ),
    .o_idu_ldstbp (idu_ldstbp   ),
    .i_exu_ldstbp (exu_ldstbp   ),
    .o_exu_rs2    (exu_rs2_bp   ),
    .s_regs       (s_regs       )
  );

  csrfile u_csrfile(
  	.i_clk           (i_clk          ),
    .i_rst_n         (i_rst_n        ),
    .i_ren           (idu_csrsren    ),
    .i_raddr         (idu_csrsid     ),
    .o_rdata         (idu_csrs       ),
    .i_wen           (wbu_csrdwen    ),
    .i_waddr         (wbu_csrdid     ),
    .i_wdata         (wbu_csrd       ),
    .i_mepc_wen      (mepc_wen       ),
    .i_mepc_wdata    (mepc_wdata     ),
    .i_mcause_wen    (mcause_wen     ),
    .i_mcause_wdata  (mcause_wdata   ),
    .i_mstatus_wen   (mstatus_wen    ),
    .i_mstatus_wdata (mstatus_wdata  ),
    .o_mtvec         (mtvec          ),
    .o_mstatus       (mstatus        ),
    .o_mepc          (mepc           ),
    .o_mip           (mip            ),
    .o_mie           (mie            ),
    .i_clint_mtip    (clint_mtip     ),
    .s_mtvec         (s_mtvec        ),
    .s_mepc          (s_mepc         ),
    .s_mstatus       (s_mstatus      ),
    .s_mcause        (s_mcause       ),
    .s_mcycle        (s_mcycle       ),
    .s_mie           (s_mie          ),
    .s_mip           (s_mip          )
  );

  // 2.7 bru ///////////////////////////////////////////////

  bru u_bru(
    .i_clk       (i_clk        ),
    .i_rst_n     (i_rst_n      ),
    .i_idu_valid (idu_valid    ),
    .i_idu_rs1id (idu_rs1id    ),
    .i_exu_rdid  (exu_rdid     ),
    .i_jal       (idu_jal      ),
    .i_jalr      (idu_jalr     ),
    .i_brch      (idu_brch     ),
    .i_bfun3     (idu_bfun3    ),
    .i_rs1       (idu_rs1      ),
    .i_rs2       (idu_rs2      ),
    .i_imm       (idu_imm      ),
    .i_ifupc     (ifu_pc       ),
    .i_idupc     (idu_pc       ),
    .i_iru_excp  (iru_excp     ),
    .i_iru_intr  (iru_intr     ),
    .i_iru_pc    (iru_pc       ),
    .o_next_pc   (pre_pc       ),
    .o_ifid_nop  (ifid_nop     )
  );

  // 3.difftest: ///////////////////////////////////////////////////////////////////////////////////////////////
  reg                   cmt_wen   ;
  reg [7:0]             cmt_wdest ;
  reg [`CPU_WIDTH-1:0]  cmt_wdata ;
  reg [`CPU_WIDTH-1:0]  cmt_pc    ;
  reg [31:0]            cmt_inst  ;
  reg                   cmt_valid ;
  reg                   cmt_skip  ;
  reg [`CPU_WIDTH-1:0]  cmt_intrNO;
  reg                   trap      ;
  reg [7:0]             trap_code ;
  reg [63:0]            cycleCnt  ;
  reg [63:0]            instrCnt  ;
  reg [`CPU_WIDTH-1:0]  regs_diff [`REG_COUNT-1:0];

  wire real_cmt = !wbu_nop & wbu_commit;
  assign s_uart_out_valid = real_cmt & (cmt_inst == `CPU_WIDTH'h7b);
  assign s_uart_out_char = s_regs[10][7:0];

  wire csr_mcycle = real_cmt & (cmt_inst[6: 0] == `TYPE_SYS & cmt_inst[31:20] == `ADDR_MCYCLE);
  wire cmt_skip = s_uart_out_valid | csr_mcycle | s_wbu_lsclint;

  always @(negedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      {cmt_wen, cmt_wdest, cmt_wdata, cmt_pc, cmt_inst, cmt_valid, cmt_intrNO, trap, trap_code, cycleCnt, instrCnt} <= 0;
    end
    else if (~trap) begin
      cmt_wen   <= wbu_rdwen;
      cmt_wdest <= {3'd0, wbu_rdid};
      cmt_wdata <= wbu_rd   ;
      cmt_pc    <= wbu_pc   ;
      cmt_inst  <= wbu_ins  ;
      cmt_valid <= real_cmt ; 
      cmt_intrNO<= (iru_intr & wbu_ready) ? s_mcause : 0; // 中断号，非0时产生中断。产生中断的时钟周期中，DifftestInstrCommit提交的valid需为0
      regs_diff <= s_regs   ;

      trap      <= (wbu_ins[6:0] == 7'h6b) ;
      trap_code <= s_regs[10][7:0]           ;
      cycleCnt  <= cycleCnt + 1              ;
      instrCnt  <= instrCnt + wbu_commit     ;
    end
  end

  DifftestInstrCommit DifftestInstrCommit(
    .clock              (i_clk),
    .coreid             (0),
    .index              (0),
    .valid              (cmt_valid),
    .pc                 (cmt_pc   ),
    .instr              (cmt_inst ),
    .skip               (cmt_skip ),
    .special(),
    .isRVC              (0        ),
    .scFailed           (0        ),
    .wen                (cmt_wen  ),
    .wdest              (cmt_wdest),
    .wdata              (cmt_wdata)
  );

  DifftestArchIntRegState DifftestArchIntRegState (
    .clock              (i_clk),
    .coreid             (0    ),
    .gpr_0              (regs_diff[ 0]),
    .gpr_1              (regs_diff[ 1]),
    .gpr_2              (regs_diff[ 2]),
    .gpr_3              (regs_diff[ 3]),
    .gpr_4              (regs_diff[ 4]),
    .gpr_5              (regs_diff[ 5]),
    .gpr_6              (regs_diff[ 6]),
    .gpr_7              (regs_diff[ 7]),
    .gpr_8              (regs_diff[ 8]),
    .gpr_9              (regs_diff[ 9]),
    .gpr_10             (regs_diff[10]),
    .gpr_11             (regs_diff[11]),
    .gpr_12             (regs_diff[12]),
    .gpr_13             (regs_diff[13]),
    .gpr_14             (regs_diff[14]),
    .gpr_15             (regs_diff[15]),
    .gpr_16             (regs_diff[16]),
    .gpr_17             (regs_diff[17]),
    .gpr_18             (regs_diff[18]),
    .gpr_19             (regs_diff[19]),
    .gpr_20             (regs_diff[20]),
    .gpr_21             (regs_diff[21]),
    .gpr_22             (regs_diff[22]),
    .gpr_23             (regs_diff[23]),
    .gpr_24             (regs_diff[24]),
    .gpr_25             (regs_diff[25]),
    .gpr_26             (regs_diff[26]),
    .gpr_27             (regs_diff[27]),
    .gpr_28             (regs_diff[28]),
    .gpr_29             (regs_diff[29]),
    .gpr_30             (regs_diff[30]),
    .gpr_31             (regs_diff[31])
  );

  DifftestTrapEvent DifftestTrapEvent(
    .clock              (i_clk    ),
    .coreid             (0        ),
    .valid              (trap     ),
    .code               (trap_code),
    .pc                 (cmt_pc   ),
    .cycleCnt           (cycleCnt ),
    .instrCnt           (instrCnt )
  );

  DifftestCSRState DifftestCSRState(
    .clock              (i_clk),
    .coreid             (0),
    .priviledgeMode     (`RISCV_PRIV_MODE_M),
    .mstatus            (s_mstatus),
    .sstatus            (0),
    .mepc               (s_mepc),
    .sepc               (0),
    .mtval              (0),
    .stval              (0),
    .mtvec              (s_mtvec),
    .stvec              (0),
    .mcause             (s_mcause),
    .scause             (0),
    .satp               (0),
    .mip                (0), //(s_mip),
    .mie                (s_mie),
    .mscratch           (0),
    .sscratch           (0),
    .mideleg            (0),
    .medeleg            (0)
  );

  DifftestArchEvent DifftestArchEvent (
    .clock         (i_clk     ),
    .coreid        (0         ),
    .intrNO        (cmt_intrNO), // 中断号，非0时产生中断。产生中断的时钟周期中，DifftestInstrCommit提交的valid需为0
    .cause         (0         ), // 异常号，ecall时不需要考虑
    .exceptionPC   (cmt_pc    ), // 产生异常时的PC
    .exceptionInst (cmt_inst  )  // 产生异常时的指令
  );

  DifftestArchFpRegState DifftestArchFpRegState(
    .clock              (i_clk),
    .coreid             (0),
    .fpr_0              (0),
    .fpr_1              (0),
    .fpr_2              (0),
    .fpr_3              (0),
    .fpr_4              (0),
    .fpr_5              (0),
    .fpr_6              (0),
    .fpr_7              (0),
    .fpr_8              (0),
    .fpr_9              (0),
    .fpr_10             (0),
    .fpr_11             (0),
    .fpr_12             (0),
    .fpr_13             (0),
    .fpr_14             (0),
    .fpr_15             (0),
    .fpr_16             (0),
    .fpr_17             (0),
    .fpr_18             (0),
    .fpr_19             (0),
    .fpr_20             (0),
    .fpr_21             (0),
    .fpr_22             (0),
    .fpr_23             (0),
    .fpr_24             (0),
    .fpr_25             (0),
    .fpr_26             (0),
    .fpr_27             (0),
    .fpr_28             (0),
    .fpr_29             (0),
    .fpr_30             (0),
    .fpr_31             (0)
  );

endmodule
