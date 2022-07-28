module booth_wallace_mult_top #(
	parameter WIDTH = 66
)(
	input  [ WIDTH-1 :0] A,
	input  [ WIDTH-1 :0] B,
	output [2*WIDTH-1:0] P//discard high bit
);
	parameter BOOTH_WIDTH = 33;
	parameter MUL_WIDTH = 132;

//1. generate booth code //////////////////////////////////
	wire  [WIDTH:0] p[BOOTH_WIDTH-1:0];
	wire  c [BOOTH_WIDTH-1:0];
genvar i;
generate 
	for(i=0; i<BOOTH_WIDTH; i=i+1)begin
		if(i==0)
			booth_encode#(
				.WIDTH ( WIDTH )
			)u_booth_encode0(
				.x ( A ),
				.s ( {B[1:0], 1'b0} ),
				.p ( p[0] ),
				.c ( c[0] )
			);
		else
			booth_encode#(
				.WIDTH ( WIDTH )
			)u_booth_encode(
				.x ( A ),
				.s ( B[2*i+1 : 2*i-1] ),
				.p ( p[i] ),
				.c ( c[i] )
			);
	end
endgenerate

//2.partial product/////////////////////////////////
	wire [2*WIDTH-1:0] tree_in [BOOTH_WIDTH-1:0];
	genvar j;
	generate	// with modified sign extension
		assign tree_in[ 0] = {{(WIDTH-1){c[0]}} , p[0]	};
		for(i=1; i<BOOTH_WIDTH; i=i+1)begin:gen_tree_in
			assign tree_in[i] = {{(WIDTH-1-2*i){c[i]}}, p[i], 1'b0, c[i-1], {(2*i-2){1'b0}}};
		end
	endgenerate

//3.Wallace tree level 7//////////////////////////
wallace_tree u_watree(
    .in(tree_in),
    .out(P)
);
endmodule
