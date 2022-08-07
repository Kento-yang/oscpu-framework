`include "rvseed_defines.sv"
module wb_stage(
    input                                     clk      ,
    input                                     rst_n    ,

    input            [`INST_WIDTH-1:0]           mem_inst   ,
    input                                     mem_reg_wen,
    input         [`REG_ADDR_WIDTH-1 : 0]     mem_reg_waddr,  // register write address
    input         [`DATA_WIDTH-1:0]           mem_regld    ,
    input         [`DATA_WIDTH-1:0]           mem_alu_res    ,
    input         [`LSU_OPT_WIDTH-1:0]        mem_lsu_opt ,
    input             [`PC_WIDTH-1:0]             mem_diff_pc,
//CSR
    input logic   [`CSR_ADDR_WIDTH-1:0]      mem_csr_raddr,
    input logic                              mem_csr_wen,
    input logic   [`DATA_WIDTH - 1:0]        mem_csr_rdata,
    input logic   [`CSR_ADDR_WIDTH-1:0]      mem_csr_waddr,

    output            [`DATA_WIDTH-1:0]          wb_reg_wdata,
    output     logic   [`PC_WIDTH-1:0]            wb_diff_pc  ,
    output     logic   [`INST_WIDTH-1:0]          wb_inst     ,
    output    logic  [`REG_ADDR_WIDTH-1 : 0]     wb_reg_waddr,                  // register write address
    output     logic                              wb_reg_wen,
//CSR
    output logic   [`CSR_ADDR_WIDTH-1:0]      wb_csr_raddr,
    output logic                              wb_csr_wen,
    output logic   [`DATA_WIDTH - 1:0]        wb_csr_rdata,
    output logic   [`CSR_ADDR_WIDTH-1:0]      wb_csr_waddr,
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
    logic                              pipe_wen = valid_mem2wb && ready_wb2mem;
    //logic  [`DATA_WIDTH-1:0]           mem_regld    ;

 
    
    
    logic  [`DATA_WIDTH-1:0]           wb_regld   ;
    logic  [`DATA_WIDTH-1:0]           wb_alu_res ;
    logic  [`LSU_OPT_WIDTH-1:0]        wb_lsu_opt ;


    //assign mem_regld = regld;
    
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
    .mem_csr_raddr(mem_csr_raddr),
    .mem_csr_wen(mem_csr_wen),
    .mem_csr_rdata(mem_csr_rdata),
    .mem_csr_waddr(mem_csr_waddr),

    .wb_inst                           (wb_inst                   ),
    .wb_reg_wen                        (wb_reg_wen                ),
    .wb_reg_waddr                      (wb_reg_waddr              ),
    .wb_regld                          (wb_regld                  ),
    .wb_alu_res                        (wb_alu_res                ),
    .wb_lsu_opt                        (wb_lsu_opt                ),
    .wb_diff_pc                        (wb_diff_pc                ),
    .wb_csr_raddr(wb_csr_raddr),
    .wb_csr_wen(wb_csr_wen),
    .wb_csr_rdata(wb_csr_rdata),
    .wb_csr_waddr(wb_csr_waddr) 
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
    .valid_pre_i  ( valid_mem2wb  ),
    .ready_next_i ( ready_next_i ),
    .valid_o_next ( valid_o_next ),
    .ready_o_pre  ( ready_wb2mem  )
);
endmodule