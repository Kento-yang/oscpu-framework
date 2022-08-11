`include "rvseed_defines.sv"
module mux_bypass #(
	parameter DATA_WIDTH = 64,
	parameter SEL_WIDTH = 3
)(
	input [DATA_WIDTH-1:0] ex_mem_bypass_data,
	input [DATA_WIDTH-1:0] mem_regld,
	input [DATA_WIDTH-1:0] mem_wb_bypass_data,
	input [DATA_WIDTH-1:0] wb_reg_bypass_data,
	input [DATA_WIDTH-1:0] id_reg_rdata,
	input lden_mem,
	input [SEL_WIDTH-1:0]  bypass_ctl,
	
	output [DATA_WIDTH-1:0]id_arb_rdata
    );
	
	assign id_arb_rdata = bypass_ctl[2] ? ex_mem_bypass_data : 
					(bypass_ctl[1] ? (lden_mem ? mem_regld : mem_wb_bypass_data) : 
					(bypass_ctl[0] ? wb_reg_bypass_data : id_reg_rdata)) ;

endmodule
