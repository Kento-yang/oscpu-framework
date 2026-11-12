`include "rvseed_defines.sv"
module rca #(
    parameter DATA_WIDTH = 128
)(
    input  [DATA_WIDTH-1:0] op1,
    input  [DATA_WIDTH-1:0] op2,
    
    input  cin,
    output [DATA_WIDTH-1:0] sum,
    output cout
);

//add make option for avoiding false cycle loop.
wire [DATA_WIDTH:0] temp/*verilator split_var*/;

assign temp[0] = cin;
assign cout = temp[DATA_WIDTH];

//assign temp_r = temp;

genvar i;
generate 
for( i=0; i<DATA_WIDTH; i=i+1) begin:ADD
    full_adder u_full_adder(
        .a      (   op1[i]     ),
        .b      (   op2[i]     ),
        .cin    (   temp[i]    ),
        .cout   (   temp[i+1]  ),
        .s      (   sum[i]     )
    );

end
endgenerate

endmodule
