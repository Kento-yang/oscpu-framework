`include "vsrc/rvseed_defines.sv"
module if_id (
  input                                     clk      ,
  input                                     rst_n    ,
  input                                     pipe_wen ,
  input                                     bubble,

  input         [`INST_WIDTH-1:0]           if_inst  ,
  input         [`PC_WIDTH-1:0]             if_pc    ,

  output logic  [`INST_WIDTH-1:0]           id_inst   ,
  output logic  [`PC_WIDTH-1:0]             id_pc     , 
  output logic  [`PC_WIDTH-1:0]             id_diff_pc    

);

  logic [`INST_WIDTH-1:0]   tem_inst; 
  logic [`PC_WIDTH-1:0]     tem_pc;     // t means temp;
  logic [`PC_WIDTH-1:0]     tem_diff_pc; //delay 5 cycle ,use for sim 
  
  // 0x13 == ADDI x0,x0,0 == nop.
  assign tem_inst  = bubble  ? `INST_WIDTH'h13 : if_inst;
  assign tem_pc    = if_pc;  
  assign tem_diff_pc = bubble ? `PC_WIDTH'h0  : if_pc;
  //assign t_ifu_diffpc = i_bubble ? `CPU_WIDTH'b0  : i_ifu_pc;   // use for sim, branch bubble diffpc == 0;

  Reg #(
    .WIDTH      (2*`PC_WIDTH+`INST_WIDTH),
    .RESET_VAL  (0                    )
  ) if_id_reg(
  	.clk      (clk                 ),
    .rst_n    (rst_n               ),
    .wen      (pipe_wen            ),
    .din      ({tem_inst,  tem_pc ,tem_diff_pc }),
    .dout     ({id_inst,  id_pc ,id_diff_pc })
  );
  
endmodule