`include "rvseed_defines.sv"
//`include "vsrc/StdLib/Reg.sv"

module mem_wb (
  input                                     clk       ,
  input                                     rst_n     ,
  input                                     pipe_wen ,

  input            [`INST_WIDTH-1:0]           mem_inst   ,
  input                                     mem_reg_wen,
  input         [`REG_ADDR_WIDTH-1 : 0]     mem_reg_waddr,  // register write address
  input         [`DATA_WIDTH-1:0]           mem_regld    ,
  input         [`DATA_WIDTH-1:0]           mem_alu_res    ,
  input         [`LSU_OPT_WIDTH-1:0]        mem_lsu_opt ,
  input             [`PC_WIDTH-1:0]             mem_diff_pc,

  output logic            [`INST_WIDTH-1:0]           wb_inst   ,
  output logic                              wb_reg_wen,   
  output logic  [`REG_ADDR_WIDTH-1 : 0]     wb_reg_waddr,  // register write address

  output logic  [`DATA_WIDTH-1:0]           wb_regld   ,
  output logic  [`DATA_WIDTH-1:0]           wb_alu_res ,
  output logic  [`LSU_OPT_WIDTH-1:0]        wb_lsu_opt ,
  output logic             [`PC_WIDTH-1:0]             wb_diff_pc
 
);
  logic [`INST_WIDTH-1:0]           tem_inst   ;
  logic                              tem_reg_wen;   
  logic  [`REG_ADDR_WIDTH-1 : 0]     tem_reg_waddr;  // register write address

  logic  [`DATA_WIDTH-1:0]           tem_regld   ;
  logic  [`DATA_WIDTH-1:0]           tem_alu_res ;
  logic  [`LSU_OPT_WIDTH-1:0]        tem_lsu_opt ;

 assign tem_inst = mem_inst;
  assign tem_reg_wen = mem_reg_wen;
  assign tem_reg_waddr = mem_reg_waddr;
  assign tem_regld = mem_regld;
  assign tem_alu_res = mem_alu_res;
  assign tem_lsu_opt = mem_lsu_opt;

  Reg #(
    .WIDTH      (`INST_WIDTH + 1 + `REG_ADDR_WIDTH + 2*`DATA_WIDTH + `LSU_OPT_WIDTH + `PC_WIDTH),
    .RESET_VAL  (0                    )
  ) if_id_reg(
  	.clk      (clk                ),
    .rst_n    (rst_n              ),
    .wen      (pipe_wen                ),
    .din      ({tem_inst, tem_reg_wen,  tem_reg_waddr, tem_regld, tem_alu_res, tem_lsu_opt,mem_diff_pc}),
    .dout     ({wb_inst, wb_reg_wen,  wb_reg_waddr, wb_regld, wb_alu_res, wb_lsu_opt,wb_diff_pc})
  );

  
endmodule