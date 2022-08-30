`include "rvseed_defines.sv"
module wb_stage(
    input                                     clk      ,
    input                                     rst_n    ,
    input logic                         flush,
    input logic [`PC_WIDTH-1:0] cmt_wb_diff_pc,
    
    input pipe_exmem_wen,
    input            [`INST_WIDTH-1:0]           mem_inst   ,
    input                                     mem_reg_wen,
    input         [`REG_ADDR_WIDTH-1 : 0]     mem_reg_waddr,  // register write address
    input         [`DATA_WIDTH-1:0]           mem_regld    ,
    input         [`DATA_WIDTH-1:0]           mem_alu_res    ,
    input         [`LSU_OPT_WIDTH-1:0]        mem_lsu_opt ,
    input             [`PC_WIDTH-1:0]             mem_diff_pc,
    input mem_clint_ldst,
//CSR

    input logic   [`DATA_WIDTH - 1:0]        mem_csr_wdata,
    input logic   [`CSR_ADDR_WIDTH-1:0]      mem_csr_waddr,
    input logic                              mem_csr_wen,

    output            [`DATA_WIDTH-1:0]          wb_reg_wdata,
    output     logic   [`PC_WIDTH-1:0]            wb_diff_pc  ,
    output     logic   [`INST_WIDTH-1:0]          wb_inst     ,
    output    logic  [`REG_ADDR_WIDTH-1 : 0]     wb_reg_waddr,                  // register write address
    output     logic                              wb_reg_wen,
//CSR
    output logic wb_clint_ldst,
    output logic   [`DATA_WIDTH - 1:0]        wb_csr_wdata,
    output logic   [`CSR_ADDR_WIDTH-1:0]      wb_csr_waddr,
    output logic                              wb_csr_wen,
//handshake signal
    input valid_mem2wb,
    input ready_next_i,
    //input data_in, 
    
    output valid_o_next,
    output ready_wb2mem

);
//------------------------------------------------------------------------------
//  EX-WB REG  
//------------------------------------------------------------------------------
    wire                              pipe_wen = valid_mem2wb && ready_wb2mem;
    //logic  [`DATA_WIDTH-1:0]           mem_regld    ;

    
    logic  [`DATA_WIDTH-1:0]           wb_regld   ;
    logic  [`DATA_WIDTH-1:0]           wb_alu_res ;
    logic  [`LSU_OPT_WIDTH-1:0]        wb_lsu_opt ;


    //assign mem_regld = regld;
    
mem_wb u_mem_wb(
    .clk                               (clk                       ),
    .rst_n                             (rst_n                     ),
    .flush                             (flush                     ),
    .pipe_wen                          (/*(wb_diff_pc == 'b1) ? pipe_exmem_wen:*/pipe_wen),
    .cmt_wb_diff_pc                    (cmt_wb_diff_pc),

    .mem_inst                          (mem_inst                  ),
    .mem_reg_wen                       (mem_reg_wen               ),
    .mem_reg_waddr                     (mem_reg_waddr             ),
    .mem_regld                         (mem_regld                 ),
    .mem_alu_res                       (mem_alu_res               ),
    .mem_lsu_opt                       (mem_lsu_opt               ),
    .mem_diff_pc                       (mem_diff_pc               ),
    .mem_clint_ldst(mem_clint_ldst),
    .mem_csr_wdata(mem_csr_wdata),
    .mem_csr_waddr(mem_csr_waddr),
    .mem_csr_wen(mem_csr_wen),

    .wb_inst                           (wb_inst                   ),
    .wb_reg_wen                        (wb_reg_wen                ),
    .wb_reg_waddr                      (wb_reg_waddr              ),
    .wb_regld                          (wb_regld                  ),
    .wb_alu_res                        (wb_alu_res                ),
    .wb_lsu_opt                        (wb_lsu_opt                ),
    .wb_diff_pc                        (wb_diff_pc                ),
    .wb_clint_ldst(wb_clint_ldst),
    
    .wb_csr_wdata(wb_csr_wdata),
    .wb_csr_waddr(wb_csr_waddr),
    .wb_csr_wen(wb_csr_wen)
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

pipehandshake u_pipehandshake(
    .clk          ( clk          ),
    .rst_n        ( rst_n        ),
    .valid_pre_i  ( flush? 0:valid_mem2wb  ),
    .ready_next_i ( ready_next_i ),
    .valid_o_next ( valid_o_next ),
    .ready_o_pre  ( ready_wb2mem  )
);
endmodule