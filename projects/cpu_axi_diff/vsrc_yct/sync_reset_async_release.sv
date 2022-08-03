`include "rvseed_defines.sv"
module sync_reset_async_release(
    input logic clock,
    input logic reset_n,
    output logic rst_n
);

    logic rst_nr1, rst_nr2;
 
    always @(posedge clock or negedge reset_n) begin
        if(!reset_n) begin
			rst_nr1 <= 1'b0;
            rst_nr2 <= 1'b0;		//异步复位
        end
        else begin
			rst_nr1 <= 1'b1;
			rst_nr2 <= rst_nr1;		//同步释放
		end
    end
	
	assign rst_n = rst_nr2;			

endmodule		
