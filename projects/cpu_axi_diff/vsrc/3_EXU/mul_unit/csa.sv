
module csa #(
	parameter DATA_WIDTH = 128
)(
	input [DATA_WIDTH-1:0] op1,
	input [DATA_WIDTH-1:0] op2,
	input [DATA_WIDTH-1:0] op3/*verilator split_var*/,
	
	output [DATA_WIDTH-1:0] S,
	output [DATA_WIDTH-1:0] C
);
    wire [DATA_WIDTH-1:0] g;
    wire [DATA_WIDTH-1:0] p;
genvar i;
generate
	for(i=0; i<DATA_WIDTH; i++) begin
		assign g[i] = op1[i] & op2[i];
        assign p[i] = op1[i] ^ op2[i];
        assign S[i] = p[i] ^ op3[i];
	    assign C[i] = op3[i] & p[i] | g[i] ;
	end
endgenerate

endmodule
