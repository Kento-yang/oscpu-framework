`include "rvseed_defines.sv"
//`include "vsrc/utils/syncex_pc_reset_async_release.sv"
//handshake top

module top (
    input                                        clk                        ,
    input                                        reset_n                    ,
    //input              [`INST_WIDTH-1:0]         inst                       ,//for DPIC read inst
    //input     logic    [`PC_WIDTH-1 : 0]         curr_pc                    ,

//interface for simtop
    output                              if_valid,
    input                               if_ready,
    input  [63:0]                       if_data_read,
    output [63:0]                       if_addr,
    output [1:0]                        if_size,
    input  [1:0]                        if_resp


    //output    logic    [`PC_WIDTH-1 : 0]         next_pc                    ,//for DPIC update
    //output    logic    [`DATA_WIDTH-1:0]         reg10_a0                    
);
    logic    [`PC_WIDTH-1 : 0]         next_pc;           
    logic    [`DATA_WIDTH-1:0]         reg10_a0;                    

    //for align pc with reg wr, and generate special pc means data/jump adventure.
    logic   [`PC_WIDTH-1:0]     id_diff_pc  ,
                                ex_diff_pc  ,
                                mem_diff_pc ,
                                wb_diff_pc  ;
    //for  inst
    logic   [`INST_WIDTH-1:0]   if_inst     ,
                                id_inst     , 
                                ex_inst     , 
                                mem_inst    , 
                                wb_inst     ;
    //assign if_inst = inst;
//------------------------------------------------------------------------------
// Reset_tree.
//------------------------------------------------------------------------------
    logic                       rst_n;

sync_reset_async_release u_reset_tree(
    .clock                             (clk                       ),
    .reset_n                           (reset_n                   ),
    
    .rst_n                             (rst_n                     ) 
);
//------------------------------------------------------------------------------
//  1.IF STAGE
//------------------------------------------------------------------------------
    logic                       bubble_id_ex;
//handshake
    logic   ready_id2if; 
    logic   valid_if2id = 1;
    logic   fetched;
    logic   if_pc;
if_stage u_if_stage(
    .clk                               (clk                       ),
    .rst_n                             (rst_n                     ),

    .if_valid                          (if_valid                  ),
    .if_ready                          (if_ready                  ),
    .if_data_read                      (if_data_read              ),
    .if_addr                           (if_addr                   ),
    .if_size                           (if_size                   ),
    .if_resp                           (if_resp                   ),
    .fetched                           (fetched                   ),

    //.curr_pc                           (curr_pc                   ),
    .ex_pc                             (ex_pc                     ),
    .ex_branch                         (ex_branch                 ),
    .ex_zero                           (ex_zero                   ),
    .ex_jump                           (ex_jump                   ),
    .ex_imm                            (ex_imm                    ),
    .ex_reg1_rdata                     (ex_reg1_rdata             ),
    .ex_jalr                           (ex_jalr                   ),
    .bubble_id_ex                      (bubble_id_ex              ),

    .if_inst                           (if_inst                   ),
    .if_pc                             (if_pc                     ),
    .next_pc                           (next_pc                   ),
    .bpu_bubble                        (bpu_bubble                ), 
    
    .ready_next_i                      (ready_id2if               ),
    .valid_o_next                      (valid_if2id               ) 
);
//------------------------------------------------------------------------------
//  2.ID STAGE
//------------------------------------------------------------------------------
    logic pipe_wen_id;
    logic bpu_bubble;
    //from wbu
    logic                              wb_reg_wen;//from mem_wb
    logic  [`REG_ADDR_WIDTH-1 : 0]     wb_reg_waddr; 
    logic   [`DATA_WIDTH-1:0]          wb_reg_wdata;

    logic   [`REG_ADDR_WIDTH-1 : 0]    ex_reg1_raddr;
    logic   [`REG_ADDR_WIDTH-1 : 0]    ex_reg2_raddr;
    logic   [`REG_ADDR_WIDTH-1 : 0]    ex_reg_waddr;                // register write address
    logic                              ex_reg_wen;
    logic   [`LSU_OPT_WIDTH-1 : 0]     ex_lsu_opt;
      
    logic    [`REG_ADDR_WIDTH-1 : 0]     mem_reg_waddr;              // register write address   
    logic                                mem_reg_wen;
    logic    [`LSU_OPT_WIDTH-1 : 0]      mem_lsu_opt;
    logic    [`DATA_WIDTH-1:0]           mem_alu_res;

    logic    [`DATA_WIDTH-1:0]           ex_alu_res;

    logic  [`DATA_WIDTH-1:0]           mem_regld   ;

    logic            [`PC_WIDTH-1:0]            id_pc   ;
    logic                                       id_branch;
    logic                                       id_jump;
    logic                                       id_jalr;
    logic                                       id_reg_wen;
    logic            [`REG_ADDR_WIDTH-1 : 0]    id_reg_waddr;  // register write address
    logic            [`REG_ADDR_WIDTH-1 : 0]    id_reg1_raddr;  // register1 rd address
    logic            [`REG_ADDR_WIDTH-1 : 0]    id_reg2_raddr;  // register2 rd address
    logic            [`DATA_WIDTH-1:0]          id_arb_rdata1;
    logic            [`DATA_WIDTH-1:0]          id_arb_rdata2;
    logic            [`DATA_WIDTH-1:0]          id_imm;        // immediate
    logic            [`ALU_OP_WIDTH-1 : 0]      id_alu_op;
    logic            [`ALU_SRC_WIDTH-1 : 0]     id_alu_src_sel;
    logic            [`LSU_OPT_WIDTH-1 : 0]     id_lsu_opt; 
//to ex mux_ldst_bp
     logic                              bp_ld_st_ctrl;
//handshake
logic ready_ex2id ,valid_id2ex;
wire [`REG_BUS] regs[0 : 31];//for difftest
id_stage u_id_stage(
    .clk                               (clk                       ),
    .rst_n                             (rst_n                     ),
    .pipe_wen                          (pipe_wen_id                  ),
    //.bubble                            (bubble                    ),
    .bpu_bubble                        (bpu_bubble                ),
    .wb_reg_wen                        (wb_reg_wen                ),
    .wb_reg_waddr                      (wb_reg_waddr              ),
    .wb_reg_wdata                      (wb_reg_wdata              ),
    .ex_reg1_raddr                     (ex_reg1_raddr             ),
    .ex_reg2_raddr                     (ex_reg2_raddr             ),
    .ex_reg_waddr                      (ex_reg_waddr              ),
    .ex_reg_wen                        (ex_reg_wen                ),
    .ex_lsu_opt                        (ex_lsu_opt                ),
    .mem_reg_waddr                     (mem_reg_waddr             ),
    .mem_reg_wen                       (mem_reg_wen               ),
    .mem_lsu_opt                       (mem_lsu_opt               ),
    .mem_alu_res                       (mem_alu_res               ),
    .ex_alu_res                        (ex_alu_res                ),
    .mem_regld                         (mem_regld                 ),

    .if_inst                           (if_inst                   ),
    .if_pc                             (if_pc                     ),

    .id_inst                           (id_inst                   ),
    .id_pc                             (id_pc                     ),
    .id_branch                         (id_branch                 ),
    .id_jump                           (id_jump                   ),
    .id_jalr                           (id_jalr                   ),
    .id_reg_wen                        (id_reg_wen                ),
    .id_reg_waddr                      (id_reg_waddr              ),
    .id_reg1_raddr                     (id_reg1_raddr             ),
    .id_reg2_raddr                     (id_reg2_raddr             ),
    .id_arb_rdata1                     (id_arb_rdata1             ),
    .id_arb_rdata2                     (id_arb_rdata2             ),
    .id_imm                            (id_imm                    ),
    .id_alu_op                         (id_alu_op                 ),
    .id_alu_src_sel                    (id_alu_src_sel            ),
    .id_lsu_opt                        (id_lsu_opt                ),
    .id_diff_pc                        (id_diff_pc                ),
    .reg10_a0                          (reg10_a0                  ),
    .bubble_id_ex                      (bubble_id_ex              ),
    .bp_ld_st_ctrl                     (bp_ld_st_ctrl             ),

    .regs                              (regs                      ),//for difftest
    .valid_pre_i                       (valid_if2id               ),
    .ready_next_i                      (ready_ex2id              ),
    .valid_o_next                      (valid_id2ex              ),
    .ready_o_pre                       (ready_id2if             ) 
);
//------------------------------------------------------------------------------
//  3.EX STAGE
//------------------------------------------------------------------------------
    logic   [`PC_WIDTH-1:0]     ex_pc;
    logic                       ex_branch;                          // ex_branch type 
    logic                       ex_zero;                            // alu result is ex_zero
    logic                       ex_jump;                            // ex_jump type 
    logic   [`DATA_WIDTH-1:0]   ex_imm;                             // immediate  
    logic   [`DATA_WIDTH-1:0]   ex_reg1_rdata;                      // rs1    ex_jalr:rs1+ex_imm
    logic                       ex_jalr;
    logic             [`DATA_WIDTH-1:0]          ex_regst     ;     //ex_reg2_rdata
    logic                       ex_alu_res_valid;
//handshake
    logic ready_mem2ex, valid_ex2mem;
ex_stage u_ex_stage(
    .clk                               (clk                       ),
    .rst_n                             (rst_n                     ),
    .bpu_bubble                        (bpu_bubble                ),
    .bubble_id_ex                      (bubble_id_ex              ),
    .bp_ld_st_ctrl                     (bp_ld_st_ctrl             ),
    .mem_regld                         (mem_regld                 ),

    .id_inst                           (id_inst                   ),
    .id_pc                             (id_pc                     ),
    .id_branch                         (id_branch                 ),
    .id_jump                           (id_jump                   ),
    .id_jalr                           (id_jalr                   ),
    .id_reg_wen                        (id_reg_wen                ),
    .id_reg_waddr                      (id_reg_waddr              ),
    .id_reg1_raddr                     (id_reg1_raddr             ),
    .id_reg2_raddr                     (id_reg2_raddr             ),
    .id_arb_rdata1                     (id_arb_rdata1             ),
    .id_arb_rdata2                     (id_arb_rdata2             ),
    .id_imm                            (id_imm                    ),
    .id_alu_op                         (id_alu_op                 ),
    .id_alu_src_sel                    (id_alu_src_sel            ),
    .id_lsu_opt                        (id_lsu_opt                ),
    .id_diff_pc                        (id_diff_pc                ),

    .ex_pc                             (ex_pc                     ),
    .ex_branch                         (ex_branch                 ),
    .ex_zero                           (ex_zero                   ),
    .ex_jalr                           (ex_jalr                   ),
    .ex_jump                           (ex_jump                   ),
    .ex_imm                            (ex_imm                    ),
    .ex_reg1_rdata                     (ex_reg1_rdata             ),
    .ex_inst                           (ex_inst                   ),
    .ex_reg_wen                        (ex_reg_wen                ),
    .ex_reg_waddr                      (ex_reg_waddr              ),
    .ex_alu_res                        (ex_alu_res                ),
    .ex_regst                          (ex_regst                  ),
    .ex_lsu_opt                        (ex_lsu_opt                ),
    .ex_diff_pc                        (ex_diff_pc                ),
    .ex_alu_res_valid                  (ex_alu_res_valid),//div res valid signal.

    .valid_pre_i                       (valid_id2ex               ),
    .ready_next_i                      (ready_mem2ex              ),
    .valid_o_next                      (valid_ex2mem              ),
    .ready_o_pre                       (ready_ex2id  ) 
);

//------------------------------------------------------------------------------
//  4.MEM STAGE
//------------------------------------------------------------------------------
//handshake
    logic                                   ready_wb2mem = 1, valid_mem2wb;
mem_stage u_mem_stage(
    .clk                               (clk                       ),
    .rst_n                             (rst_n                     ),
    .ex_inst                           (ex_inst                   ),
    .ex_reg_wen                        (ex_reg_wen                ),
    .ex_reg_waddr                      (ex_reg_waddr              ),
    .ex_alu_res                        (ex_alu_res                ),
    .ex_regst                          (ex_regst                  ),
    .ex_lsu_opt                        (ex_lsu_opt                ),
    .ex_diff_pc                        (ex_diff_pc                ),

    .mem_inst                          (mem_inst                  ),
    .mem_reg_wen                       (mem_reg_wen               ),
    .mem_reg_waddr                     (mem_reg_waddr             ),
    .mem_alu_res                       (mem_alu_res               ),
    .mem_lsu_opt                       (mem_lsu_opt               ),
    .mem_diff_pc                       (mem_diff_pc               ),
    .mem_regld                         (mem_regld                 ),

    .valid_pre_i                       (valid_ex2mem               ),
    .ready_next_i                      (ready_wb2mem              ),
    .valid_o_next                      (valid_mem2wb              ),
    .ready_o_pre                       (ready_mem2ex               ) 
);
//------------------------------------------------------------------------------
//  5.WB STAGE
//------------------------------------------------------------------------------
wb_stage u_wb_stage(
    .clk                               (clk                       ),
    .rst_n                             (rst_n                     ),
    .mem_inst                          (mem_inst                  ),
    .mem_reg_wen                       (mem_reg_wen               ),
    .mem_reg_waddr                     (mem_reg_waddr             ),
    .mem_regld                         (mem_regld                 ),
    .mem_alu_res                       (mem_alu_res               ),
    .mem_lsu_opt                       (mem_lsu_opt               ),
    .mem_diff_pc                       (mem_diff_pc               ),

    .wb_reg_wdata                      (wb_reg_wdata              ),
    .wb_diff_pc                        (wb_diff_pc                ),
    .wb_inst                           (wb_inst                   ),
    .wb_reg_waddr                      (wb_reg_waddr              ),
    .wb_reg_wen                        (wb_reg_wen                ),

    .valid_pre_i                       (valid_mem2wb               ),
    .ready_next_i                      (               ),
    .valid_o_next                      (               ),
    .ready_o_pre                       (ready_wb2mem               ) 
);

//------------------------------------------------------------------------------
//  XiangShan Difftest
//------------------------------------------------------------------------------
reg cmt_wen;
reg [7:0] cmt_wdest;
reg [`REG_BUS] cmt_wdata;
reg [`REG_BUS] cmt_pc;
reg [31:0] cmt_inst;
reg cmt_valid;
reg trap;
reg [7:0] trap_code;
reg [63:0] cycleCnt;
reg [63:0] instrCnt;
reg [`REG_BUS] regs_diff [0 : 31];

wire inst_valid = fetched;

always @(negedge clk) begin
  if (!rst_n) begin
    {cmt_wen, cmt_wdest, cmt_wdata, cmt_pc, cmt_inst, cmt_valid, trap, trap_code, cycleCnt, instrCnt} <= 0;
  end
  else if (~trap) begin
    cmt_wen <= wb_reg_wen;//rd_w_ena;
    cmt_wdest <= {3'd0, wb_reg_waddr};//{3'd0, rd_w_addr};
    cmt_wdata <= wb_reg_wdata;//rd_data;
    cmt_pc <= if_pc;//pc;
    cmt_inst <= wb_inst;//inst;
    cmt_valid <= inst_valid;//inst_valid;

    regs_diff <= regs;

    trap <= wb_inst[6:0] == 7'h6b;
    trap_code <= regs[10][7:0];
    cycleCnt <= cycleCnt + 1;
    instrCnt <= instrCnt + inst_valid;
  end
end

DifftestInstrCommit DifftestInstrCommit(
  .clock              (clk),
  .coreid             (0),
  .index              (0),
  .valid              (cmt_valid),
  .pc                 (cmt_pc),
  .instr              (cmt_inst),
  .special (),
  .skip               (0),
  .isRVC              (0),
  .scFailed           (0),
  .wen                (cmt_wen),
  .wdest              (cmt_wdest),
  .wdata              (cmt_wdata)
);

DifftestArchIntRegState DifftestArchIntRegState (
  .clock              (clk),
  .coreid             (0),
  .gpr_0              (regs_diff[0]),
  .gpr_1              (regs_diff[1]),
  .gpr_2              (regs_diff[2]),
  .gpr_3              (regs_diff[3]),
  .gpr_4              (regs_diff[4]),
  .gpr_5              (regs_diff[5]),
  .gpr_6              (regs_diff[6]),
  .gpr_7              (regs_diff[7]),
  .gpr_8              (regs_diff[8]),
  .gpr_9              (regs_diff[9]),
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
  .clock              (clk),
  .coreid             (0),
  .valid              (trap),
  .code               (trap_code),
  .pc                 (cmt_pc),
  .cycleCnt           (cycleCnt),
  .instrCnt           (instrCnt)
);

DifftestCSRState DifftestCSRState(
  .clock              (clk),
  .coreid             (0),
  .priviledgeMode     (`RISCV_PRIV_MODE_M),
  .mstatus            (0),
  .sstatus            (0),
  .mepc               (0),
  .sepc               (0),
  .mtval              (0),
  .stval              (0),
  .mtvec              (0),
  .stvec              (0),
  .mcause             (0),
  .scause             (0),
  .satp               (0),
  .mip                (0),
  .mie                (0),
  .mscratch           (0),
  .sscratch           (0),
  .mideleg            (0),
  .medeleg            (0)
);

DifftestArchFpRegState DifftestArchFpRegState(
  .clock              (clk),
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
//------------------------------------------------------------------------------
//  FOR SIM USE DPIC 
//------------------------------------------------------------------------------

/*
import "DPI-C" function bit ebreak_check(input int in_inst);
always_comb begin:BREAKSIM
    if(ebreak_check(wb_inst) == 1 )begin
        $display("input inst = 0x%08x is ebreak!",wb_inst);
        if(reg10_a0 == `DATA_WIDTH'b0)
            $display(">>>>>>>>>>>>>>>>HIT GOOD TRAP!!<<<<<<<<<<<<<<<<<");
        else
            $display(">>>>>>>>>>>>>>>>HIT BAD TRAP!!<<<<<<<<<<<<<<<<<");
        $finish();
    end
end

import "DPI-C" function void diff_read_pc(input longint rtl_pc);
always_comb begin
    diff_read_pc(wb_diff_pc);
end

import "DPI-C" function void diff_read_ready_ex2id(input bit rtl_ready_ex2id);
always_comb begin
    diff_read_ready_ex2id(valid_mem2wb);
end*/

endmodule


