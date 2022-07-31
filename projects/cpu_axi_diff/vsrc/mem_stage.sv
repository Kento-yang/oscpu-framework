`include "rvseed_defines.sv"
module mem_stage(
    input                                     clk      ,
    input                                     rst_n    ,

    input             [`INST_WIDTH-1:0]           ex_inst   ,
    input                                       ex_reg_wen,
    input             [`REG_ADDR_WIDTH-1 : 0]   ex_reg_waddr,  // register write address
    input             [`DATA_WIDTH-1:0]         ex_alu_res    ,
    input             [`DATA_WIDTH-1:0]         ex_regst    ,//ex_regst
    input             [`LSU_OPT_WIDTH-1 : 0]    ex_lsu_opt    ,
    input            [`PC_WIDTH-1:0]             ex_diff_pc,

    output         [`INST_WIDTH-1:0]           mem_inst   ,
    output                                    mem_reg_wen,
    output        [`REG_ADDR_WIDTH-1 : 0]     mem_reg_waddr,  // register write address
    output        [`DATA_WIDTH-1:0]           mem_alu_res    ,
    output        [`LSU_OPT_WIDTH-1:0]        mem_lsu_opt ,
    output            [`PC_WIDTH-1:0]             mem_diff_pc,

    output        [`DATA_WIDTH-1:0]           mem_regld    ,


  //handshake signal
    input valid_ex2mem,
    input ready_wb2mem,
    //input data_in, 
    
    output valid_mem2wb,
    output ready_mem2ex

);
//------------------------------------------------------------------------------
//  EX-MEM REG  
//------------------------------------------------------------------------------
   logic                               pipe_wen = valid_ex2mem && ready_mem2ex;
   //logic    [`DATA_WIDTH-1:0]           ex_alu_res;
   logic    [`DATA_WIDTH-1:0]           mem_reg2_rdata;


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
    logic   [`DATA_WIDTH-1:0]           regld;// for ld.

lsu u0_lsu(
    .clk                               (clk                       ),
    .rst_n                             (rst_n                     ),

    .lsu_opt                           (mem_lsu_opt               ),// lsu i_opt.
    .addr                              (mem_alu_res               ),// mem i_addr. from exu result.
    .regst                             (mem_reg2_rdata            ),// for st. M[x[rs1]+imm]X[rs2][63:0]
    
    .regld                             (mem_regld                 ) // for ld.
);

pipehandshake u_pipehandshake(
    .clk          ( clk          ),
    .rst_n        ( rst_n        ),
    .valid_pre_i  ( valid_ex2mem  ),
    .ready_next_i ( ready_wb2mem ),
    .valid_o_next ( valid_mem2wb ),
    .ready_o_pre  ( ready_mem2ex  )
);

endmodule