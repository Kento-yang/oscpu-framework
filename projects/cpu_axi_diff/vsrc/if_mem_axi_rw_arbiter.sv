`include "rvseed_defines.sv"
module if_mem_axi_rw_arbiter(
    input                               clk                        ,
    input                               reset_n                    ,
//IF INTTERFACE
    input                               if_valid                   ,
    output                              if_ready                   ,
    input                               if_req                 ,
    output             [  63:0]         if_data_read               ,
    input              [  63:0]         if_addr                    ,
    input              [   1:0]         if_size                    ,
    output             [   1:0]         if_resp                    ,
//MEM INTTERFACE
    input                               mem_valid                  ,
    output                              mem_ready                  ,
    input                               mem_req                 ,
    output             [  63:0]         mem_data_read              ,
    input              [  63:0]         mem_data_write             ,
    input              [  63:0]         mem_addr                   ,
    input              [   1:0]         mem_size                   ,
    output             [   1:0]         mem_resp                   ,
    input              [   7:0]         mem_wmask                  ,
//output
    output    logic grant,    
    output                              rw_valid_i                 ,
    input                               rw_ready_o                 ,
    output                              rw_req_i                   ,
    input              [  63:0]         data_read_o                ,
    output             [  63:0]         data_write_i               ,
    output             [  63:0]         rw_addr_i                  ,
    output             [   1:0]         rw_size_i                  ,
    input              [   1:0]         rw_resp_o                  ,
    output             [   7:0]         rw_wmask                  
);
//------------------------------------------------------------------------------
//  IF-MEM Arbiter
//------------------------------------------------------------------------------
    localparam MASTER_0 = 1'b0, MASTER_1 = 1'b1;
 
    always @(posedge clk) begin
        if(!reset_n)
            grant <= MASTER_0;
        else if(mem_valid && mem_ready)
            grant <= MASTER_0; 
        else if(if_valid && if_ready && mem_valid )
            grant <= MASTER_1;
    end

    assign rw_valid_i    = (grant == MASTER_1) ? mem_valid  : if_valid;
    assign rw_req_i      = (grant == MASTER_1) ? mem_req  : if_req;
    assign data_write_i  = (grant == MASTER_1) ? mem_data_write  : 64'b0;
    assign rw_addr_i     = (grant == MASTER_1) ? mem_addr  : if_addr;
    assign rw_size_i     = (grant == MASTER_1) ? mem_size  : if_size;
    assign rw_wmask      = (grant == MASTER_1) ? mem_wmask : 8'b0;

    assign mem_ready     = (grant == MASTER_1) ? rw_ready_o  : 1'b0;
    assign mem_data_read = (grant == MASTER_1) ? data_read_o : 1'b0;
    assign mem_resp      = (grant == MASTER_1) ? data_read_o : 1'b0;
    
    assign if_ready      = (grant == MASTER_1) ? 1'b0 : rw_ready_o ;
    assign if_data_read  = (grant == MASTER_1) ? 1'b0 : data_read_o;
    assign if_resp       = (grant == MASTER_1) ? 1'b0 : data_read_o;
endmodule