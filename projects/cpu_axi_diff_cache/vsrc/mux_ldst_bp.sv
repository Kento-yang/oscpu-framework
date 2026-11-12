`include "rvseed_defines.sv"
module mux_ldst_bp #(
parameter DATA_WIDTH = 64,
parameter SEL_WIDTH = 3

)(
	input [DATA_WIDTH-1:0] mem_regld,
	input [DATA_WIDTH-1:0] ex_reg2_rdata,
	input   bp_ld_st_ctrl,

	output [DATA_WIDTH-1:0] ex_regst
    );
	
	assign ex_regst = bp_ld_st_ctrl ? mem_regld : ex_reg2_rdata ;

endmodule
