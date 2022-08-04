`include "rvseed_defines.sv"
module id_stage(
    input                                     clk      ,
    input                                     rst_n    ,

    //input                                     pipe_wen ,
    //input                                     bubble,
//from IF bpu
    input logic                       bpu_bubble,
//from wbu
    input logic                              wb_reg_wen,//from mem_wb
    input logic  [`REG_ADDR_WIDTH-1 : 0]     wb_reg_waddr, 
    input logic   [`DATA_WIDTH-1:0]          wb_reg_wdata,
//from id_ex_reg
    input logic   [`REG_ADDR_WIDTH-1 : 0]    ex_reg1_raddr,
    input logic   [`REG_ADDR_WIDTH-1 : 0]    ex_reg2_raddr,
    input logic   [`REG_ADDR_WIDTH-1 : 0]    ex_reg_waddr,                 // register write address
    input logic                              ex_reg_wen,
    input logic   [`LSU_OPT_WIDTH-1 : 0]     ex_lsu_opt,
    input logic            [`PC_WIDTH-1:0]      ex_diff_pc,//for ld-add adventure use
//from ex_mem   
    input logic    [`REG_ADDR_WIDTH-1 : 0]     mem_reg_waddr,              // register write address   
    input logic                                mem_reg_wen,
    input logic    [`LSU_OPT_WIDTH-1 : 0]      mem_lsu_opt,
    input logic    [`DATA_WIDTH-1:0]           mem_alu_res,
    input logic mem_valid,
    input logic mem_ready,
    input logic mem_req,
    input logic mem_grant,
//from alu
    input logic    [`DATA_WIDTH-1:0]           ex_alu_res,
//from mem lsu
    input logic  [`DATA_WIDTH-1:0]           mem_regld    ,

    input         [`INST_WIDTH-1:0]           if_inst  ,
    input         [`PC_WIDTH-1:0]             if_pc    ,

    //output logic  [`INST_WIDTH-1:0]           id_inst   ,
    //output logic  [`PC_WIDTH-1:0]             id_pc     , 
    //output logic  [`PC_WIDTH-1:0]             id_diff_pc   
    output   logic  [`INST_WIDTH-1:0]           id_inst   ,
    output            [`PC_WIDTH-1:0]            id_pc   ,
    output                                       id_branch,
    output                                       id_jump,
    output                                       id_jalr,
    output                                       id_reg_wen,
    output            [`REG_ADDR_WIDTH-1 : 0]    id_reg_waddr,  // register write address
    output            [`REG_ADDR_WIDTH-1 : 0]    id_reg1_raddr,  // register1 rd address
    output            [`REG_ADDR_WIDTH-1 : 0]    id_reg2_raddr,  // register2 rd address
    output            [`DATA_WIDTH-1:0]          id_arb_rdata1,
    output            [`DATA_WIDTH-1:0]          id_arb_rdata2,
    output            [`DATA_WIDTH-1:0]          id_imm,        // immediate
    output            [`ALU_OP_WIDTH-1 : 0]      id_alu_op,
    output            [`ALU_SRC_WIDTH-1 : 0]     id_alu_src_sel,
    output            [`LSU_OPT_WIDTH-1 : 0]     id_lsu_opt,
    output logic id_lsu_lden,
    output logic id_lsu_sten,
    output           [`PC_WIDTH-1:0]             id_diff_pc,    

//to the top DPIC detect good/bad trap
    output logic    [`DATA_WIDTH-1:0]         reg10_a0,
//bubble
    output logic                              bubble_id_ex,
//to ex mux_ldst_bp
    output logic                              bp_ld_st_ctrl,
    output  wire [`REG_BUS] regs[0 : 31],
//handshake signal
    input valid_if2id,
    input ready_ex2id,
    //input data_in, 
    
    output valid_id2ex,
    output ready_id2if
    //output data_out 

);
//------------------------------------------------------------------------------
//  IF-ID REG   
//------------------------------------------------------------------------------

    //logic   [`PC_WIDTH-1:0]     if_pc    ;
    //logic   [`PC_WIDTH-1:0]     id_pc    ;
    //logic pipe_wen = ~bubble_id_ex && valid_if2id && ready_id2if;

    logic pipe_wen;
    assign pipe_wen = ~bubble_id_ex && valid_if2id && ready_id2if ;
if_id u1_if_id(
    .clk                               (clk                       ),
    .rst_n                             (rst_n                     ),
    .pipe_wen                          (pipe_wen),//if bypass bubble,if_id pipe stall
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
    //logic                              id_branch;
    //logic                              id_jump;
    //logic                              id_reg_wen;
    logic   [`IMM_GEN_OP_WIDTH-1:0]    id_imm_gen_op;

decode u1_decode(
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
    .lsu_lden(id_lsu_lden),
    .lsu_sten(id_lsu_sten),
    .jalr                              (id_jalr                   ) 
);

    //logic   [`DATA_WIDTH-1:0]          id_imm;               // immediate
imm_gen u1_imm_gen(
    .inst                              (id_inst                   ),
    .imm_gen_op                        (id_imm_gen_op             ),

    .imm                               (id_imm                    ) 
);

    logic   [`DATA_WIDTH-1:0]          id_reg1_rdata;
    logic   [`DATA_WIDTH-1:0]          id_reg2_rdata;

reg_file u1_reg_file(
    .clk                               (clk                       ),
    .rst_n                             (rst_n                     ),
    .reg_wen                           (wb_reg_wen                ),//from wbu write wen
    .reg_waddr                         (wb_reg_waddr              ),//from wbu write addr
    .reg_wdata                         (wb_reg_wdata              ),//from wbu write data
    .reg1_raddr                        (id_reg1_raddr             ),
    .reg2_raddr                        (id_reg2_raddr             ),

    .reg1_rdata                        (id_reg1_rdata             ),
    .reg2_rdata                        (id_reg2_rdata             ),

    .regs_o                            (regs)
);


// bypass in ID cycle ////////////////
    
    logic   [2:0 ]                     bypass_src1_ctl;
    logic   [2:0 ]                     bypass_src2_ctl;
    

    
    //logic   [`REG_ADDR_WIDTH-1 : 0]    ex_reg_waddr;                // register write address
    //logic   [`REG_ADDR_WIDTH-1 : 0]    ex_reg1_raddr;
    //logic   [`REG_ADDR_WIDTH-1 : 0]    ex_reg2_raddr;
    logic   [`DATA_WIDTH-1:0]          ex_reg2_rdata;
    logic   [`ALU_OP_WIDTH-1 : 0]      ex_alu_op;
    logic   [`ALU_SRC_WIDTH-1 : 0]     ex_alu_src_sel;
    //logic   [`LSU_OPT_WIDTH-1 : 0]     ex_lsu_opt;

data_bypass u1_data_bypass(
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

mux_bypass#(
    .DATA_WIDTH                        (64                        ),
    .SEL_WIDTH                         (3                         ) 
)u1_src1_mux_bypass(
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
)u1_src2_mux_bypass(
    .ex_mem_bypass_data                (ex_alu_res                ),
    .mem_regld                         (mem_regld                 ),
    .mem_wb_bypass_data                (mem_alu_res               ),
    .wb_reg_bypass_data                (wb_reg_wdata              ),
    .id_reg_rdata                      (id_reg2_rdata             ),
    .bypass_ctl                        (bypass_src2_ctl           ),
    .lden_mem                          (~mem_lsu_opt[0]           ),

    .id_arb_rdata                      (id_arb_rdata2             ) 
);

logic valid_id2ex_r;
//当LD-ADD冒险发生时，如果mem成功读到数据，并且需要旁路的时候，valid可以为高
//需要旁路通过bubble_id_ex判断，bubble_id_ex虽然只有一个cycle脉冲，但是会让ex的diff_pc一直为1，用此信号告知发生了LD-ADD型冒险。
assign valid_id2ex = valid_id2ex_r || (mem_valid && mem_ready && (mem_grant == 1) && (mem_req == 0) && (ex_diff_pc =='b1)); //ld-add adventure solve, when mem read data and hs
pipehandshake u1_pipehandshake(
    .clk          ( clk          ),
    .rst_n        ( rst_n        ),

    .valid_pre_i  ( valid_if2id  ),
    .ready_next_i ( ready_ex2id ),

    .valid_o_next ( valid_id2ex_r ),
    .ready_o_pre  ( ready_id2if  )
);

endmodule