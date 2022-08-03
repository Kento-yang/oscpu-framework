`include "rvseed_defines.sv"

module wbu( 
  input         [`DATA_WIDTH-1:0]  exu_res,
  input         [`DATA_WIDTH-1:0]  lsu_res,
  input                            ld_en,
  
  output logic  [`DATA_WIDTH-1:0]  rd     
);
  
  assign rd = ld_en ? lsu_res : exu_res; //only load en =1
    
endmodule