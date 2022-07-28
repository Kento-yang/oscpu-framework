`include "vsrc/rvseed_defines.sv"
//`include "vsrc/utils/syncex_pc_reset_async_release.sv"
//Release 1.0
//5 pipeline without handshake

module top_without_handshake (
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
//------------------------------------------------------------------------------
// Reset_tree.
//------------------------------------------------------------------------------
    logic                       rst_n;

sync_reset_async_release u0_reset_tree(
    .clock                             (clk                       ),
    .reset_n                           (reset_n                   ),
    
    .rst_n                             (rst_n                     ) 
);
//------------------------------------------------------------------------------
//  1.IF 
//------------------------------------------------------------------------------
    //for bpu
    logic   [`PC_WIDTH-1:0]     ex_pc;
    logic                       ex_branch;                          // ex_branch type 
    logic                       ex_zero;                            // alu result is ex_zero
    logic                       ex_jump;                            // ex_jump type 
    logic   [`DATA_WIDTH-1:0]   ex_imm;                            // immediate  
    logic   [`DATA_WIDTH-1:0]   ex_reg1_rdata;                     // rs1    ex_jalr:rs1+ex_imm
    logic                       ex_jalr;

    logic                       pc_add_imm_flag;
    logic   [`PC_WIDTH-1:0]     bpu_pc_update;
    logic                       bpu_bubble;
bpu u_bpu(
    .ex_pc                             (ex_pc                     ),
    .ex_branch                         (ex_branch                 ),
    .ex_zero                           (ex_zero                   ),
    .ex_jump                           (ex_jump                   ),
    .ex_imm                            (ex_imm                    ),
    .ex_reg1_rdata                     (ex_reg1_rdata             ),
    .ex_jalr                           (ex_jalr                   ),

    .pc_add_imm_flag                   (pc_add_imm_flag           ),
    .bpu_pc_update                     (bpu_pc_update             ),
    .bubble                            (bpu_bubble                ) 
);

    logic   [`PC_WIDTH-1:0]     curr_pc_update;
mux_pc u_mux_pc(
    .curr_pc                           (curr_pc                   ),
    .bpu_pc_update                     (bpu_pc_update             ),
    .pc_add_imm_flag                   (pc_add_imm_flag           ),
    
    .curr_pc_update                    (curr_pc_update            ) 
);

    logic                       pc_wen = ~bubble_id_ex;
pc_update u0_pc_update(
    .clk                               (clk                       ),// system clock
    .rst_n                             (rst_n                     ),// active low reset
    .pc_wen                            (pc_wen                    ),// system enable
    .curr_pc_update                    (curr_pc_update            ),// current pc addr

    .next_pc                           (next_pc                   ) // used for DPIC INST Fetch
);
//------------------------------------------------------------------------------
//  IF-ID REG   
//------------------------------------------------------------------------------

    logic   [`PC_WIDTH-1:0]     if_pc    ;
    logic   [`PC_WIDTH-1:0]     id_pc    ;

    assign if_inst  = inst;
    assign if_pc    = curr_pc;

if_id u_if_id(
    .clk                               (clk                       ),
    .rst_n                             (rst_n                     ),
    .pipe_wen                          (~bubble_id_ex             ),//if bypass bubble,if_id pipe stall
    .bubble                            (bpu_bubble                ),//from bpu

    .if_inst                           (if_inst                   ),
    .if_pc                             (if_pc                     ),

    .id_inst                           (id_inst                   ),
    .id_pc                             (id_pc                     ),
    .id_diff_pc                        (id_diff_pc                ) 
);
//------------------------------------------------------------------------------
//  2.ID  
//------------------------------------------------------------------------------
    logic                              id_branch;
    logic                              id_jump;
    logic                              id_reg_wen;
    logic   [`REG_ADDR_WIDTH-1 : 0]    id_reg1_raddr;
    logic   [`REG_ADDR_WIDTH-1 : 0]    id_reg2_raddr;
    logic   [`REG_ADDR_WIDTH-1 : 0]    id_reg_waddr;         // register write address
    logic   [`IMM_GEN_OP_WIDTH-1:0]    id_imm_gen_op;
    logic   [`ALU_OP_WIDTH-1 : 0]      id_alu_op;
    logic   [`ALU_SRC_WIDTH-1 : 0]     id_alu_src_sel;
    logic   [`LSU_OPT_WIDTH-1 : 0]     id_lsu_opt;
    logic                              id_jalr;


decode u0_decode(
    .inst                              (id_inst                   ),

    .branch                            (id_branch                 ),
    .jump                              (id_jump                   ),
    .reg_wen                           (id_reg_wen                ),
    .reg1_raddr                        (id_reg1_raddr             ),
    .reg2_raddr                        (id_reg2_raddr             ),
    .reg_waddr                         (id_reg_waddr              ),
    .imm_gen_op                        (id_imm_gen_op             ),
    .alu_op                            (id_alu_op                 ),
    .alu_src_sel                       (id_alu_src_sel            ),
    .lsu_opt                           (id_lsu_opt                ),
    .jalr                              (id_jalr                   ) 
);

    logic   [`DATA_WIDTH-1:0]          id_imm;               // immediate
imm_gen u0_imm_gen(
    .inst                              (id_inst                   ),
    .imm_gen_op                        (id_imm_gen_op             ),

    .imm                               (id_imm                    ) 
);

    logic   [`DATA_WIDTH-1:0]          wb_reg_wdata;

    logic   [`DATA_WIDTH-1:0]          id_reg1_rdata;
    logic   [`DATA_WIDTH-1:0]          id_reg2_rdata;
    logic    [`DATA_WIDTH-1:0]         id_reg10_a0;

    assign reg10_a0 = id_reg10_a0;

reg_file u0_reg_file(
    .clk                               (clk                       ),
    .rst_n                             (rst_n                     ),
    .reg_wen                           (wb_reg_wen                ),//from wbu write wen
    .reg_waddr                         (wb_reg_waddr              ),//from wbu write addr
    .reg_wdata                         (wb_reg_wdata              ),//from wbu write data
    .reg1_raddr                        (id_reg1_raddr             ),
    .reg2_raddr                        (id_reg2_raddr             ),

    .reg1_rdata                        (id_reg1_rdata             ),
    .reg2_rdata                        (id_reg2_rdata             ),
    .reg10_a0                          (id_reg10_a0               ) 
);


// bypass in ID cycle ////////////////
    logic                              bubble_id_ex;
    logic   [2:0 ]                     bypass_src1_ctl;
    logic   [2:0 ]                     bypass_src2_ctl;
    logic                              bp_ld_st_ctrl;

    logic                              ex_reg_wen;
    logic   [`REG_ADDR_WIDTH-1 : 0]    ex_reg_waddr;                // register write address
    logic   [`REG_ADDR_WIDTH-1 : 0]    ex_reg1_raddr;
    logic   [`REG_ADDR_WIDTH-1 : 0]    ex_reg2_raddr;
    logic   [`DATA_WIDTH-1:0]          ex_reg2_rdata;
    logic   [`ALU_OP_WIDTH-1 : 0]      ex_alu_op;
    logic   [`ALU_SRC_WIDTH-1 : 0]     ex_alu_src_sel;
    logic   [`LSU_OPT_WIDTH-1 : 0]     ex_lsu_opt;

data_bypass u_data_bypass(
    .reg1_raddr_id                     (id_reg1_raddr             ),
    .reg2_raddr_id                     (id_reg2_raddr             ),
    .reg1_raddr_ex                     (ex_reg1_raddr             ),
    .reg2_raddr_ex                     (ex_reg2_raddr             ),

    .reg_waddr_ex                      (ex_reg_waddr              ),
    .reg_waddr_mem                     (mem_reg_waddr             ),
    .reg_waddr_wb                      (wb_reg_waddr              ),

    .reg_wen_ex                        (ex_reg_wen                ),
    .reg_wen_mem                       (mem_reg_wen               ),
    .reg_wen_wb                        (wb_reg_wen                ),

    .sten_ex                           (ex_lsu_opt                ),//ex阶段st指令
    .sten_mem                          (mem_lsu_opt               ),//mem阶段st指令
    .lden_ex                           (~ex_lsu_opt[0]            ),
    .lden_mem                          (~mem_lsu_opt[0]           ),//mem阶段ld指令
    
    .bubble_id_ex                      (bubble_id_ex              ),

    .bp_alu_src1_ctrl                  (bypass_src1_ctl           ),
    .bp_alu_src2_ctrl                  (bypass_src2_ctl           ),
    .bp_ld_st_ctrl                     (bp_ld_st_ctrl             ) 
);

    logic   [`DATA_WIDTH-1:0]           id_arb_rdata1,
                                        id_arb_rdata2;

mux_bypass#(
    .DATA_WIDTH                        (64                        ),
    .SEL_WIDTH                         (3                         ) 
)u_src1_mux_bypass(
    .ex_mem_bypass_data                (ex_alu_res                ),
    .mem_regld                         (mem_regld                 ),
    .mem_wb_bypass_data                (mem_alu_res               ),//如果是ld指令，这块有问题。需要传regld值
    .wb_reg_bypass_data                (wb_reg_wdata              ),//如果用wb_alu_res ld的数据不传过来了就
    .id_reg_rdata                      (id_reg1_rdata             ),
    .bypass_ctl                        (bypass_src1_ctl           ),
    .lden_mem                          (~mem_lsu_opt[0]           ),

    .id_arb_rdata                      (id_arb_rdata1             ) 
);

mux_bypass#(
    .DATA_WIDTH                        (64                        ),
    .SEL_WIDTH                         (3                         ) 
)u_src2_mux_bypass(
    .ex_mem_bypass_data                (ex_alu_res                ),
    .mem_regld                         (mem_regld                 ),
    .mem_wb_bypass_data                (mem_alu_res               ),
    .wb_reg_bypass_data                (wb_reg_wdata              ),
    .id_reg_rdata                      (id_reg2_rdata             ),
    .bypass_ctl                        (bypass_src2_ctl           ),
    .lden_mem                          (~mem_lsu_opt[0]           ),

    .id_arb_rdata                      (id_arb_rdata2             ) 
);
//------------------------------------------------------------------------------
//  ID-EX REG  
//------------------------------------------------------------------------------
    logic                               pipe_wen = 1;

id_ex u_id_ex(
    .clk                               (clk                       ),
    .rst_n                             (rst_n                     ),
    .pipe_wen                          (pipe_wen                  ),
    .bpu_bubble                        (bpu_bubble                    ),
    .bypass_bubble                     (bubble_id_ex              ),

    .id_inst                           (id_inst                   ),
    .id_pc                             (id_pc                     ),
    .id_branch                         (id_branch                 ),
    .id_jump                           (id_jump                   ),
    .id_jalr                           (id_jalr                   ),
    .id_reg_wen                        (id_reg_wen                ),
    .id_reg_waddr                      (id_reg_waddr              ),
    .id_reg1_raddr                     (id_reg1_raddr             ),//arbiter
    .id_reg2_raddr                     (id_reg2_raddr             ),//arbiter
    .id_reg1_rdata                     (id_arb_rdata1             ),
    .id_reg2_rdata                     (id_arb_rdata2             ),
    .id_imm                            (id_imm                    ),
    .id_alu_op                         (id_alu_op                 ),
    .id_alu_src_sel                    (id_alu_src_sel            ),
    .id_lsu_opt                        (id_lsu_opt                ),
    .id_diff_pc                        (id_diff_pc                ),

    .ex_inst                           (ex_inst                   ),
    .ex_pc                             (ex_pc                     ),
    .ex_branch                         (ex_branch                 ),
    .ex_jump                           (ex_jump                   ),
    .ex_jalr                           (ex_jalr                   ),
    .ex_reg_wen                        (ex_reg_wen                ),
    .ex_reg_waddr                      (ex_reg_waddr              ),
    .ex_reg1_raddr                     (ex_reg1_raddr             ),
    .ex_reg2_raddr                     (ex_reg2_raddr             ),
    .ex_reg1_rdata                     (ex_reg1_rdata             ),
    .ex_reg2_rdata                     (ex_reg2_rdata             ),
    .ex_imm                            (ex_imm                    ),
    .ex_alu_op                         (ex_alu_op                 ),
    .ex_alu_src_sel                    (ex_alu_src_sel            ),
    .ex_lsu_opt                        (ex_lsu_opt                ),
    .ex_diff_pc                        (ex_diff_pc                ) 
);
//------------------------------------------------------------------------------
//  3.EX  
//------------------------------------------------------------------------------
    logic   [`DATA_WIDTH-1:0]           ex_alu_src1;                      // alu source 1
    logic   [`DATA_WIDTH-1:0]           ex_alu_src2;                      // alu source 2

mux_alu  u_mux_alu (
    //.clk(clk),
    //.rst_n(rst_n),
    .alu_src_sel                       (ex_alu_src_sel            ),
    .reg1_rdata                        (ex_reg1_rdata             ),
    .reg2_rdata                        (ex_reg2_rdata             ),
    .imm                               (ex_imm                    ),
    .curr_pc                           (ex_pc                     ),

    .alu_src1                          (ex_alu_src1               ),
    .alu_src2                          (ex_alu_src2               ) 
);
alu u0_alu(
    .alu_op                            (ex_alu_op                 ),
    .alu_src1                          (ex_alu_src1               ),
    .alu_src2                          (ex_alu_src2               ),
    
    .alu_res                           (ex_alu_res                ),
    .zero                              (ex_zero                   ) // alu result is zero
);

    logic   [`DATA_WIDTH-1:0]           ex_regst;

mux_ldst_bp#(
    .DATA_WIDTH                        (64                        ) 
//.SEL_WIDTH     ( 3 )
)u_mux_ldst_bp(
    .mem_regld                         (mem_regld                 ),
    .ex_reg2_rdata                     (ex_reg2_rdata             ),
    .bp_ld_st_ctrl                     (bp_ld_st_ctrl             ),

    .ex_regst                          (ex_regst                  ) 
);
//------------------------------------------------------------------------------
//  EX-MEM REG  
//------------------------------------------------------------------------------
   logic    [`DATA_WIDTH-1:0]           ex_alu_res;
   logic                                mem_reg_wen;
   logic    [`REG_ADDR_WIDTH-1 : 0]     mem_reg_waddr;              // register write address
   logic    [`DATA_WIDTH-1:0]           mem_alu_res;
   logic    [`DATA_WIDTH-1:0]           mem_reg2_rdata;
   logic    [`LSU_OPT_WIDTH-1 : 0]      mem_lsu_opt;
 

ex_mem u_ex_mem(
    .clk                               (clk                       ),
    .rst_n                             (rst_n                     ),
    .pipe_wen                          (pipe_wen                  ),
    
    .ex_inst                           (ex_inst                   ),
    .ex_reg_wen                        (ex_reg_wen                ),
    .ex_reg_waddr                      (ex_reg_waddr              ),
    .ex_alu_res                        (ex_alu_res                ),
    .ex_reg2_rdata                     (ex_regst                  ),
    .ex_lsu_opt                        (ex_lsu_opt                ),
    .ex_diff_pc                        (ex_diff_pc                ),

    .mem_inst                          (mem_inst                  ),
    .mem_reg_wen                       (mem_reg_wen               ),
    .mem_reg_waddr                     (mem_reg_waddr             ),
    .mem_alu_res                       (mem_alu_res               ),
    .mem_reg2_rdata                    (mem_reg2_rdata            ),
    .mem_lsu_opt                       (mem_lsu_opt               ),
    .mem_diff_pc                       (mem_diff_pc               ) 
);
//------------------------------------------------------------------------------
//  4.MEM  
//------------------------------------------------------------------------------

lsu u0_lsu(
    .clk                               (clk                       ),
    .rst_n                             (rst_n                     ),

    .lsu_opt                           (mem_lsu_opt               ),// lsu i_opt.
    .addr                              (mem_alu_res               ),// mem i_addr. from exu result.
    .regst                             (mem_reg2_rdata            ),// for st. M[x[rs1]+imm]X[rs2][63:0]
    
    .regld                             (mem_regld                 ) // for ld.
);
//------------------------------------------------------------------------------
//  EX-WB REG  
//------------------------------------------------------------------------------
    logic  [`DATA_WIDTH-1:0]           mem_regld    ;

    logic                              wb_reg_wen;
    logic  [`REG_ADDR_WIDTH-1 : 0]     wb_reg_waddr;                  // register write address
    logic  [`DATA_WIDTH-1:0]           wb_regld   ;
    logic  [`DATA_WIDTH-1:0]           wb_alu_res ;
    logic  [`LSU_OPT_WIDTH-1:0]        wb_lsu_opt ;


mem_wb u_mem_wb(
    .clk                               (clk                       ),
    .rst_n                             (rst_n                     ),
    .pipe_wen                          (pipe_wen                  ),

    .mem_inst                          (mem_inst                  ),
    .mem_reg_wen                       (mem_reg_wen               ),
    .mem_reg_waddr                     (mem_reg_waddr             ),
    .mem_regld                         (mem_regld                 ),
    .mem_alu_res                       (mem_alu_res               ),
    .mem_lsu_opt                       (mem_lsu_opt               ),
    .mem_diff_pc                       (mem_diff_pc               ),

    .wb_inst                           (wb_inst                   ),
    .wb_reg_wen                        (wb_reg_wen                ),
    .wb_reg_waddr                      (wb_reg_waddr              ),
    .wb_regld                          (wb_regld                  ),
    .wb_alu_res                        (wb_alu_res                ),
    .wb_lsu_opt                        (wb_lsu_opt                ),
    .wb_diff_pc                        (wb_diff_pc                ) 
);
//------------------------------------------------------------------------------
//  5.WB 
//------------------------------------------------------------------------------
wbu u0_wbu(
    .exu_res                           (wb_alu_res                ),
    .lsu_res                           (wb_regld                  ),
    .ld_en                             (~wb_lsu_opt[0]            ),
    
    .rd                                (wb_reg_wdata              ) 
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

endmodule
