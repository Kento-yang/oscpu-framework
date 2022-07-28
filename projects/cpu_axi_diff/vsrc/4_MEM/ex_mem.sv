`include "vsrc/rvseed_defines.sv"
module ex_mem (
  input                                       clk       ,
  input                                       rst_n     ,
  input                                       pipe_wen       ,

  input             [`INST_WIDTH-1:0]           ex_inst   ,
  input                                       ex_reg_wen,
  input             [`REG_ADDR_WIDTH-1 : 0]   ex_reg_waddr,  // register write address
  input             [`DATA_WIDTH-1:0]         ex_alu_res    ,
  input             [`DATA_WIDTH-1:0]         ex_reg2_rdata    ,
  input             [`LSU_OPT_WIDTH-1 : 0]    ex_lsu_opt    ,
 input            [`PC_WIDTH-1:0]             ex_diff_pc,

  output logic            [`INST_WIDTH-1:0]           mem_inst   ,
  output logic                                mem_reg_wen,
  output logic      [`REG_ADDR_WIDTH-1 : 0]   mem_reg_waddr,  // register write address
  output logic      [`DATA_WIDTH-1:0]         mem_alu_res    ,
  output logic      [`DATA_WIDTH-1:0]         mem_reg2_rdata    ,
  output logic      [`LSU_OPT_WIDTH-1 : 0]    mem_lsu_opt    ,
  output logic            [`PC_WIDTH-1:0]             mem_diff_pc
);
  //logic tem_zero;
  logic        [`INST_WIDTH-1:0]     tem_inst;
  logic                                tem_reg_wen;
  logic      [`REG_ADDR_WIDTH-1 : 0]   tem_reg_waddr;  // register write address
  logic      [`DATA_WIDTH-1:0]         tem_alu_res;
  logic      [`DATA_WIDTH-1:0]         tem_reg2_rdata;
  logic      [`LSU_OPT_WIDTH-1 : 0]    tem_lsu_opt;
  //logic            [`PC_WIDTH-1:0]     tem_diff_pc;/only stage id-ex ex-mem need set tem diff pc

  //assign tem_zero = ex_zero;
  assign tem_inst = ex_inst;
  assign tem_reg_wen = ex_reg_wen;
  assign tem_reg_waddr = ex_reg_waddr;
  assign tem_alu_res = ex_alu_res;
  assign tem_reg2_rdata = ex_reg2_rdata;
  assign tem_lsu_opt = ex_lsu_opt;


  Reg #(
    .WIDTH      (`INST_WIDTH + 1 + `REG_ADDR_WIDTH + 2*`DATA_WIDTH + `LSU_OPT_WIDTH+ `PC_WIDTH),
    .RESET_VAL  (0                    )
  ) if_id_reg(
  	.clk      (clk                ),
    .rst_n    (rst_n              ),
    .wen      (pipe_wen                ),
    .din      ({tem_inst, tem_reg_wen,  tem_reg_waddr,  tem_alu_res, tem_reg2_rdata, tem_lsu_opt,ex_diff_pc}),
    .dout     ({mem_inst, mem_reg_wen,  mem_reg_waddr,  mem_alu_res, mem_reg2_rdata, mem_lsu_opt,mem_diff_pc})
  );


endmodule