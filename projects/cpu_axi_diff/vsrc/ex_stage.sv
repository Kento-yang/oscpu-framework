`include "rvseed_defines.sv"
//
module ex_stage(
    input                                     clk      ,
    input                                     rst_n    ,
    input logic                         flush,
//from bpu
    input logic                                 bpu_bubble,
//from id data_bypass
    input logic                             bubble_id_ex,
    input logic                              bp_ld_st_ctrl,
//from lsu
    input logic  [`DATA_WIDTH-1:0]           mem_regld    ,

    input  pipe_ifid_wen,
    input            [`INST_WIDTH-1:0]          id_inst   ,
    input            [`PC_WIDTH-1:0]            id_pc   ,
    input                                       id_branch,
    input                                       id_jump,
    input                                       id_jalr,
    input                                       id_reg_wen,
    input            [`REG_ADDR_WIDTH-1 : 0]    id_reg_waddr,  // register write address
    input            [`REG_ADDR_WIDTH-1 : 0]    id_reg1_raddr,  // register1 rd address
    input            [`REG_ADDR_WIDTH-1 : 0]    id_reg2_raddr,  // register2 rd address
    input            [`DATA_WIDTH-1:0]          id_arb_rdata1,  //id_arb_rdata1
    input            [`DATA_WIDTH-1:0]          id_arb_rdata2,  //id_arb_rdata2
    input            [`DATA_WIDTH-1:0]          id_imm,        // immediate
    input            [`ALU_OP_WIDTH-1 : 0]      id_alu_op,
    input            [`ALU_SRC_WIDTH-1 : 0]     id_alu_src_sel,
    input            [`LSU_OPT_WIDTH-1 : 0]     id_lsu_opt,
    input                                       id_lsu_lden,
    input                                       id_lsu_sten,
    input           [`PC_WIDTH-1:0]             id_diff_pc,  
//CSR
    input logic   [`DATA_WIDTH - 1:0]        id_csr_rdata,
    input logic   [`CSR_ADDR_WIDTH-1:0]      id_csr_waddr,
    input logic   [`CSR_IMM_WIDTH-1:0]      id_csr_zimm,    
    input logic                              id_csr_wen,

    output    logic                      pipe_idex_wen,
    output    logic   [`PC_WIDTH-1:0]     ex_pc,
    output logic                       ex_branch,                          // ex_branch type 
    output logic                       ex_zero,                            // alu result is ex_zero
    output logic                       ex_jalr,
    output logic                       ex_jump,                            // ex_jump type 
    output logic   [`DATA_WIDTH-1:0]   ex_imm,                           // immediate  
    output logic   [`DATA_WIDTH-1:0]   ex_reg1_rdata,                     // rs1    ex_jalr:rs1+ex_imm
    output             [`INST_WIDTH-1:0]           ex_inst   ,
    output                                       ex_reg_wen,
    output             [`REG_ADDR_WIDTH-1 : 0]   ex_reg_waddr,  // register write address
    output    logic   [`REG_ADDR_WIDTH-1 : 0]    ex_reg1_raddr,
    output    logic   [`REG_ADDR_WIDTH-1 : 0]    ex_reg2_raddr,
    output             [`DATA_WIDTH-1:0]         ex_alu_res    ,
    output             [`DATA_WIDTH-1:0]          ex_regst     ,//ex_reg2_rdata
    output             [`LSU_OPT_WIDTH-1 : 0]    ex_lsu_opt    ,
    output logic                                 ex_lsu_lden,
    output logic                                 ex_lsu_sten,
    output            [`PC_WIDTH-1:0]            ex_diff_pc,
    output logic                                ex_alu_res_valid,//div res valid signal.
//CSR
    
    output logic   [`DATA_WIDTH - 1:0]        ex_csr_wdata,
    output logic   [`CSR_ADDR_WIDTH-1:0]      ex_csr_waddr,
    output logic                              ex_csr_wen,
//handshake signal
    input valid_id2ex,
    input ready_mem2ex,
    //input data_in, 
    
    output valid_ex2mem,
    output ready_ex2id
);
//------------------------------------------------------------------------------
//  ID-EX REG  
//------------------------------------------------------------------------------
    logic                                pipe_wen_r;
    logic           [`PC_WIDTH-1:0]             tem_diff_pc;
    //(tem_diff_pc != ex_diff_pc)只有指令不一样的时候才能使能打拍，避免相同指令源寄存器到目标寄存器之间形成环。(rtthread 0x80004860 subw	a5,a6,a5)
    assign pipe_idex_wen =  valid_id2ex && ready_ex2id /*&& (tem_diff_pc != ex_diff_pc)*/;//shake success with id_stage


    
    logic   [`DATA_WIDTH-1:0]   ex_reg2_rdata;
    logic   [`ALU_OP_WIDTH-1 : 0]      ex_alu_op;
    logic   [`ALU_SRC_WIDTH-1 : 0]     ex_alu_src_sel;
    //logic   [`LSU_OPT_WIDTH-1 : 0]     ex_lsu_opt;
    logic   [`CSR_IMM_WIDTH-1:0]      ex_csr_zimm;    
    logic   [`DATA_WIDTH - 1:0]        ex_csr_rdata;
    
    //for ld-add adventure in icache. bubble_id_ex will flush the right pc in dummy(80000184).
    //wire real_bubble_id_ex = bubble_id_ex && !(valid_id2ex & ready_ex2id);//protect the bubble last cycle flush the right pc.

    //for bubble_id_ex destory the right pc in ld-add adventure.
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)
            pipe_wen_r <= 0;
        else
            pipe_wen_r <= pipe_idex_wen;
    end
    
id_ex u_id_ex(
    .clk                               (clk                       ),
    .rst_n                             (rst_n                     ),
    .flush                             (flush                     ),
    .pipe_wen                          (/*(ex_diff_pc == 'b1) ? pipe_ifid_wen:*/pipe_idex_wen),
    .bpu_bubble                        (bpu_bubble                ),
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
    .id_lsu_lden                       (id_lsu_lden               ),
    .id_lsu_sten                       (id_lsu_sten               ),
    .id_diff_pc                        (id_diff_pc                ),

    .id_csr_rdata                      (id_csr_rdata              ),
    .id_csr_waddr                      (id_csr_waddr              ),
    .id_csr_zimm                       (id_csr_zimm              ),
    .id_csr_wen                        (id_csr_wen                ),

    .tem_diff_pc                       (tem_diff_pc               ),

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
    .ex_lsu_lden                       (ex_lsu_lden               ),
    .ex_lsu_sten                       (ex_lsu_sten               ),
    .ex_diff_pc                        (ex_diff_pc                ),

    .ex_csr_rdata                      (ex_csr_rdata              ),
    .ex_csr_waddr                      (ex_csr_waddr              ),
    .ex_csr_zimm                       (ex_csr_zimm               ),
    .ex_csr_wen                        (ex_csr_wen                )

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
logic ex_alu_div_rem_op;
assign ex_alu_div_rem_op = (ex_alu_op ==`ALU_DIV)  || (ex_alu_op ==`ALU_DIVU)  || (ex_alu_op ==`ALU_REM)  || (ex_alu_op ==`ALU_REMU) ||  
                            (ex_alu_op ==`ALU_DIVW) || (ex_alu_op ==`ALU_DIVUW) || (ex_alu_op ==`ALU_REMW) || (ex_alu_op ==`ALU_REMUW);

/*
logic div_start;
logic ex_alu_res_valid;

logic [6:0]  cnt;
logic div_continue;
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n)
            cnt <= 0;
        else if(cnt == 'd65)begin
            cnt <= 0 ;
            div_start <= 0;
        end
        else if(alu_div_rem_op == 1 && ex_alu_src1 != 0 || div_start == 1)begin
            cnt <= cnt + 1;
            div_start <= 1;
        end
    end*/
logic div_valid_o_next, div_ready_o_pre, alu_valid_o_next;
alu u0_alu(
    .clk                               (clk                       ),
    .rst_n                             (rst_n                     ),
    .alu_op                            (ex_alu_op                 ),
    .alu_src1                          (ex_alu_src1               ),
    .alu_src2                          (ex_alu_src2               ),
    
    //.start                             (div_start                 ), 

    .alu_res                           (ex_alu_res                ),
    
    .zero                              (ex_zero                   ), // alu result is zero

    .csr_zimm                            (ex_csr_zimm),  
    .csr_rdata                          (ex_csr_rdata), 
    .csr_wdata                          (ex_csr_wdata), 

    
    .div_ready_o_pre                   (div_ready_o_pre           ),
    .div_ready_next_i                  (ready_mem2ex              ),
    .alu_valid_o_next                  (alu_valid_o_next)
);

mux_ldst_bp#(
    .DATA_WIDTH                        (64                        ) 
//.SEL_WIDTH     ( 3 )
)u_mux_ldst_bp(
    .mem_regld                         (mem_regld                 ),
    .ex_reg2_rdata                     (ex_reg2_rdata             ),
    .bp_ld_st_ctrl                     (bp_ld_st_ctrl             ),

    .ex_regst                          (ex_regst                  ) 
);


//handshake
logic valid_o_next_r, ready_o_pre_r;
assign valid_ex2mem = /*ex_alu_res_valid &&*/ valid_o_next_r && alu_valid_o_next; /*&& div_valid_o_next*/;//alu caculate finished and handshake valid = 1. 
assign ready_ex2id =  /*ex_alu_res_valid &&*/ ready_o_pre_r &&  alu_valid_o_next; //ex_alu_res_valid && ready_o_pre_r

pipehandshake u_pipehandshake(
    .clk                               (clk                       ),
    .rst_n                             (rst_n                     ),
    .valid_pre_i                       (valid_id2ex               ),
    .ready_next_i                      (ready_mem2ex              ),
    
    .valid_o_next                      (valid_o_next_r          ),
    .ready_o_pre                       (ready_o_pre_r               ) 
);

endmodule