`include "rvseed_defines.sv"
module Reg #(
  parameter WIDTH = 1, 
  parameter RESET_VAL = 0
)(
    input                          clk,
    input                          rst_n,
    input         [WIDTH-1:0]      din,

    input                          wen, 
    output logic  [WIDTH-1:0]      dout                       
);
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) 
      dout <= RESET_VAL;
    else if (wen) 
      dout <= din;
  end

endmodule