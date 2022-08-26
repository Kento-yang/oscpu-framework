`include "rvseed_defines.sv"
module id_ex (
  input                                       clk       ,
  input                                       rst_n     ,
  input logic                         flush,

  input                                       pipe_wen       ,
  input                                       bpu_bubble,
  input                                       bypass_bubble,
  input logic [`PC_WIDTH-1:0] cmt_wb_diff_pc,


  input            [`INST_WIDTH-1:0]          id_inst   ,
  input            [`PC_WIDTH-1:0]            id_pc   ,
  input                                       id_branch,
  input                                       id_jump,
  input                                       id_jalr,
  input                                       id_reg_wen,
  input            [`REG_ADDR_WIDTH-1 : 0]    id_reg_waddr,  // register write address
  input            [`REG_ADDR_WIDTH-1 : 0]    id_reg1_raddr,  // register1 rd address
  input            [`REG_ADDR_WIDTH-1 : 0]    id_reg2_raddr,  // register2 rd address
  input            [`DATA_WIDTH-1:0]          id_reg1_rdata,
  input            [`DATA_WIDTH-1:0]          id_reg2_rdata,
  input            [`DATA_WIDTH-1:0]          id_imm,        // immediate
  input            [`ALU_OP_WIDTH-1 : 0]      id_alu_op,
  input            [`ALU_SRC_WIDTH-1 : 0]     id_alu_src_sel,
  input            [`LSU_OPT_WIDTH-1 : 0]     id_lsu_opt,
  input id_lsu_lden,
  input id_lsu_sten,
  input           [`PC_WIDTH-1:0]             id_diff_pc,    
//CSR
  input   [`DATA_WIDTH - 1:0]        id_csr_rdata,
  input   [`CSR_ADDR_WIDTH-1:0]      id_csr_waddr,
  input   [`CSR_IMM_WIDTH-1:0]       id_csr_zimm,
  input                              id_csr_wen,

  output logic           [`PC_WIDTH-1:0]             tem_diff_pc,

  output logic     [`INST_WIDTH-1:0]          ex_inst   ,
  output logic     [`PC_WIDTH-1:0]            ex_pc   ,
  output logic                                ex_branch   ,
  output logic                                ex_jump,
  output logic                                ex_jalr,
  output logic                                ex_reg_wen,
  output logic     [`REG_ADDR_WIDTH-1 : 0]    ex_reg_waddr,  // register write address
  output logic     [`REG_ADDR_WIDTH-1 : 0]    ex_reg1_raddr,  // register1 rd address
  output logic     [`REG_ADDR_WIDTH-1 : 0]    ex_reg2_raddr,  // register2 rd address
  output logic     [`DATA_WIDTH-1:0]          ex_reg1_rdata   ,
  output logic     [`DATA_WIDTH-1:0]          ex_reg2_rdata   ,
  output logic     [`DATA_WIDTH-1:0]          ex_imm,
  output logic     [`ALU_OP_WIDTH-1 : 0]      ex_alu_op,
  output logic     [`ALU_SRC_WIDTH-1 : 0]     ex_alu_src_sel,
  output logic     [`LSU_OPT_WIDTH-1 : 0]     ex_lsu_opt,
  output logic ex_lsu_lden,
  output logic ex_lsu_sten,
  output logic           [`PC_WIDTH-1:0]             ex_diff_pc,
//CSR  
  output logic   [`DATA_WIDTH - 1:0]        ex_csr_rdata,
  output logic   [`CSR_ADDR_WIDTH-1:0]      ex_csr_waddr,
  output logic   [`CSR_IMM_WIDTH-1:0]      ex_csr_zimm,
  output logic                              ex_csr_wen


);
  logic     [`INST_WIDTH-1:0]           tem_inst   ;
  logic     [`PC_WIDTH-1:0]            tem_pc;
  logic                                tem_branch;
  logic                                tem_jump;
  logic                                tem_jalr;
  logic                                tem_reg_wen;
  logic     [`REG_ADDR_WIDTH-1 : 0]    tem_reg_waddr;  // register write address
  logic     [`REG_ADDR_WIDTH-1 : 0]    tem_reg1_raddr;  // register1 rd address
  logic     [`REG_ADDR_WIDTH-1 : 0]    tem_reg2_raddr;  // register2 rd address
  logic     [`DATA_WIDTH-1:0]          tem_reg1_rdata;
  logic     [`DATA_WIDTH-1:0]          tem_reg2_rdata;
  logic     [`DATA_WIDTH-1:0]          tem_imm;
  logic     [`ALU_OP_WIDTH-1 : 0]      tem_alu_op;
  logic     [`ALU_SRC_WIDTH-1 : 0]     tem_alu_src_sel;
  logic     [`LSU_OPT_WIDTH-1 : 0]     tem_lsu_opt;
  logic                                 tem_lsu_lden;
  logic                                 tem_lsu_sten;
  
  
  logic   [`DATA_WIDTH - 1:0]        tem_csr_rdata;
  logic   [`CSR_ADDR_WIDTH-1:0]      tem_csr_waddr;
  logic   [`CSR_IMM_WIDTH-1:0]      tem_csr_zimm;
  logic                              tem_csr_wen;



//if ( bypass_bubble)=1 all=0 make a nop inst
  assign tem_inst = ( bpu_bubble ||bypass_bubble) ? `INST_WIDTH'h13 :id_inst;
  assign tem_pc         = id_pc;
  assign tem_branch     = ( bpu_bubble ||bypass_bubble) ? 0 :id_branch;
  assign tem_jump       = ( bpu_bubble ||bypass_bubble) ? 0 :id_jump;
  assign tem_jalr       = ( bpu_bubble ||bypass_bubble) ? 0 :id_jalr;
  assign tem_reg_wen    = ( bpu_bubble ||bypass_bubble) ? 0 :id_reg_wen;
  assign tem_reg_waddr  = ( bpu_bubble ||bypass_bubble) ? 0 :id_reg_waddr;                   // register write address
  assign tem_reg1_raddr = ( bpu_bubble ||bypass_bubble) ? 0 :id_reg1_raddr;                 // register write address
  assign tem_reg2_raddr = ( bpu_bubble ||bypass_bubble) ? 0 :id_reg2_raddr;                 // register write address
  assign tem_reg1_rdata = ( bpu_bubble ||bypass_bubble) ? 0 :id_reg1_rdata;
  assign tem_reg2_rdata = ( bpu_bubble ||bypass_bubble) ? 0 :id_reg2_rdata;
  assign tem_imm        = ( bpu_bubble ||bypass_bubble) ? 0 :id_imm;
  assign tem_alu_op     = ( bpu_bubble ||bypass_bubble) ? `ALU_ADD :id_alu_op;
  assign tem_alu_src_sel= ( bpu_bubble ||bypass_bubble) ? `ALU_SRC_IMM : id_alu_src_sel;
  assign tem_lsu_opt    = ( bpu_bubble ||bypass_bubble) ? 0 :id_lsu_opt;
  assign tem_lsu_lden    = ( bpu_bubble ||bypass_bubble) ? 0 :id_lsu_lden;
  assign tem_lsu_sten    = ( bpu_bubble ||bypass_bubble) ? 0 :id_lsu_sten;
  assign tem_diff_pc = bpu_bubble ? `PC_WIDTH'h0 : //jump adventure
                       (bypass_bubble ? `PC_WIDTH'h1 : id_diff_pc);//data adventure

  assign tem_csr_rdata =( bpu_bubble ||bypass_bubble) ? 0 :id_csr_rdata;
  assign tem_csr_waddr =( bpu_bubble ||bypass_bubble) ? 0 :id_csr_waddr;
  assign tem_csr_zimm =( bpu_bubble ||bypass_bubble) ? 0 :id_csr_zimm;
  assign tem_csr_wen   =( bpu_bubble ||bypass_bubble) ? 0 :id_csr_wen;

  logic cmt_flush;
  assign cmt_flush = (cmt_wb_diff_pc == tem_diff_pc) ? 1 : 0;
Reg #(
    .WIDTH      (`INST_WIDTH+2*`PC_WIDTH + 4 + 3*`REG_ADDR_WIDTH + 4*`DATA_WIDTH + 
                `ALU_OP_WIDTH + `ALU_SRC_WIDTH + `LSU_OPT_WIDTH + 2 +  `CSR_ADDR_WIDTH+ `CSR_IMM_WIDTH +1),
    .RESET_VAL  (0                    )
  ) if_id_reg(
  	.clk      (clk                ),
    .rst_n    (rst_n              ),
    .wen      (flush |pipe_wen                ),
    .din      ((flush| cmt_flush) ? 0 :{tem_inst, tem_pc, tem_branch, tem_jump,  tem_jalr,
              tem_reg_wen, tem_reg_waddr, tem_reg1_raddr, tem_reg2_raddr, tem_reg1_rdata, tem_reg2_rdata, tem_imm,
              tem_alu_op, tem_alu_src_sel, tem_lsu_opt,tem_lsu_lden,tem_lsu_sten,tem_diff_pc,
              tem_csr_rdata, tem_csr_waddr, tem_csr_zimm, tem_csr_wen}),
    .dout     ({ex_inst, ex_pc, ex_branch, ex_jump,  ex_jalr,
              ex_reg_wen, ex_reg_waddr, ex_reg1_raddr, ex_reg2_raddr,  ex_reg1_rdata, ex_reg2_rdata, ex_imm,
              ex_alu_op, ex_alu_src_sel, ex_lsu_opt,ex_lsu_lden,ex_lsu_sten,ex_diff_pc,
              ex_csr_rdata, ex_csr_waddr, ex_csr_zimm, ex_csr_wen})
  );


endmodule
