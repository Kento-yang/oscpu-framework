`include "vsrc/rvseed_defines.sv"
//`include "vsrc/utils/syncex_pc_reset_async_release.sv"
//handshake top

module top (
    input                                        clk                        ,
    input                                        reset_n                    ,
    input              [`INST_WIDTH-1:0]         inst                       ,//for DPIC read inst
    input     logic    [`PC_WIDTH-1 : 0]         curr_pc                    ,

    output    logic    [`PC_WIDTH-1 : 0]         next_pc                    ,//for DPIC update
    output    logic    [`DATA_WIDTH-1:0]         reg10_a0                    
);
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
    assign if_inst = inst;
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
    logic   [`PC_WIDTH-1:0]     if_pc = curr_pc ;
//handshake
    logic   ready_id2if; 
    logic   valid_if2id = 1;
if_stage u_if_stage(
    .clk                               (clk                       ),
    .rst_n                             (rst_n                     ),
    .curr_pc                           (curr_pc                   ),
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
    //.ready_next_i                      (               ),
    //.valid_o_next                      (               ),
    .ready_o_pre                       (ready_wb2mem               ) 
);

//------------------------------------------------------------------------------
//  FOR SIM USE DPIC 
//------------------------------------------------------------------------------
/*import "DPI-C" function void rtl_pmem_read (input longint raddr, output longint rdata, input bit ren);
logic [`PC_WIDTH-1 :0]  inst;
  always @(posedge clk) begin
    rtl_pmem_read (curr_pc, inst, rst_n);
  end*/

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
end

endmodule


