/*module if_mem_axi_rw_arbiter(
    input                               clk                        ,
    input                               reset_n                    ,
//IF INTTERFACE
    output                              if_valid                   ,
    input                               if_ready                   ,
    input              [  63:0]         if_data_read               ,
    output             [  63:0]         if_addr                    ,
    output             [   1:0]         if_size                    ,
    input              [   1:0]         if_resp                    ,
//MEM INTTERFACE
    output                              mem_valid                   ,
    input                               mem_ready                   ,
    output                              mem_rw_req                  ,
    input              [  63:0]         mem_data_read               ,
    output             [  63:0]         mem_data_write              ,
    output             [  63:0]         mem_addr                    ,
    output             [   1:0]         mem_size                    ,
    input              [   1:0]         mem_resp                    ,
    output             [   7:0]         mem_wmask                   ,
//output
    input                               rw_valid_i,
	output                              rw_ready_o,
    input                               rw_req_i,
    output reg [RW_DATA_WIDTH:0]        data_read_o,
    input  [RW_DATA_WIDTH:0]            data_write_i,
    input  [AXI_DATA_WIDTH:0]           rw_addr_i,
    input  [1:0]                        rw_size_i,
    output [1:0]                        rw_resp_o,
)
    //arbitrate m1 > m0
    localparam MASTER_0 = 1'b0, MASTER_1 = 1'b1;
    logic grant;

    wire handshake;
    assign handshake = rw_valid_i & rw_ready_o;
    always @(posedge clock) begin
        if(r_state == R_STATE_IDLE  )
            grant <= (m1_rw_valid_i)? MASTER_1 : (m0_rw_valid_i)? MASTER_0 : 'b0;
        else if(w_state == W_STATE_ADDR  )
            grant <= (m1_rw_valid_i)? MASTER_1 : 'b0;
    end

    always @(*) begin
        rw_valid_i = 1'b0;
        rw_req_i = 1'b0;
        data_write_i = 'b0;
        rw_addr_i = 'b0;
        rw_size_i = 'b0;
    //priority m1 > m0
        if(m1_rw_valid_i == 1'b1) begin
            rw_valid_i = m1_rw_valid_i;
            rw_req_i = m1_rw_req_i;
            data_write_i = m1_data_write_i;
            rw_addr_i = m1_rw_addr_i;
            rw_size_i = m1_rw_size_i;
        end
        else if(m0_rw_valid_i) begin
            rw_valid_i = m0_rw_valid_i;
            rw_req_i = m0_rw_req_i;
            rw_addr_i = m0_rw_addr_i;
            rw_size_i = m0_rw_size_i;
        end
    end

    assign m1_rw_ready_o    = (m1_rw_valid_i && grant == MASTER_1)? rw_ready_o : 1'b0;          
    assign m0_rw_ready_o    = (m1_rw_valid_i && grant == MASTER_1)? 1'b0 : rw_ready_o;
    assign m1_data_read_o   = m1_rw_valid_i? data_read_o : 'b0;
    assign m0_data_read_o   = m1_rw_valid_i? 'b0 : data_read_o;
    assign m1_rw_resp_o     = m1_rw_valid_i? rw_resp_o : 'b0;
    assign m0_rw_resp_o     = m1_rw_valid_i? 'b0 : rw_resp_o;   


endmodule