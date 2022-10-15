
`include "rvseed_defines.sv"

// Burst types
`define AXI_BURST_TYPE_FIXED                                2'b00
`define AXI_BURST_TYPE_INCR                                 2'b01
`define AXI_BURST_TYPE_WRAP                                 2'b10
// Access permissions
`define AXI_PROT_UNPRIVILEGED_ACCESS                        3'b000
`define AXI_PROT_PRIVILEGED_ACCESS                          3'b001
`define AXI_PROT_SECURE_ACCESS                              3'b000
`define AXI_PROT_NON_SECURE_ACCESS                          3'b010
`define AXI_PROT_DATA_ACCESS                                3'b000
`define AXI_PROT_INSTRUCTION_ACCESS                         3'b100
// Memory types (AR)
`define AXI_ARCACHE_DEVICE_NON_BUFFERABLE                   4'b0000
`define AXI_ARCACHE_DEVICE_BUFFERABLE                       4'b0001
`define AXI_ARCACHE_NORMAL_NON_CACHEABLE_NON_BUFFERABLE     4'b0010
`define AXI_ARCACHE_NORMAL_NON_CACHEABLE_BUFFERABLE         4'b0011
`define AXI_ARCACHE_WRITE_THROUGH_NO_ALLOCATE               4'b1010
`define AXI_ARCACHE_WRITE_THROUGH_READ_ALLOCATE             4'b1110
`define AXI_ARCACHE_WRITE_THROUGH_WRITE_ALLOCATE            4'b1010
`define AXI_ARCACHE_WRITE_THROUGH_READ_AND_WRITE_ALLOCATE   4'b1110
`define AXI_ARCACHE_WRITE_BACK_NO_ALLOCATE                  4'b1011
`define AXI_ARCACHE_WRITE_BACK_READ_ALLOCATE                4'b1111
`define AXI_ARCACHE_WRITE_BACK_WRITE_ALLOCATE               4'b1011
`define AXI_ARCACHE_WRITE_BACK_READ_AND_WRITE_ALLOCATE      4'b1111
// Memory types (AW)
`define AXI_AWCACHE_DEVICE_NON_BUFFERABLE                   4'b0000
`define AXI_AWCACHE_DEVICE_BUFFERABLE                       4'b0001
`define AXI_AWCACHE_NORMAL_NON_CACHEABLE_NON_BUFFERABLE     4'b0010
`define AXI_AWCACHE_NORMAL_NON_CACHEABLE_BUFFERABLE         4'b0011
`define AXI_AWCACHE_WRITE_THROUGH_NO_ALLOCATE               4'b0110
`define AXI_AWCACHE_WRITE_THROUGH_READ_ALLOCATE             4'b0110
`define AXI_AWCACHE_WRITE_THROUGH_WRITE_ALLOCATE            4'b1110
`define AXI_AWCACHE_WRITE_THROUGH_READ_AND_WRITE_ALLOCATE   4'b1110
`define AXI_AWCACHE_WRITE_BACK_NO_ALLOCATE                  4'b0111
`define AXI_AWCACHE_WRITE_BACK_READ_ALLOCATE                4'b0111
`define AXI_AWCACHE_WRITE_BACK_WRITE_ALLOCATE               4'b1111
`define AXI_AWCACHE_WRITE_BACK_READ_AND_WRITE_ALLOCATE      4'b1111

`define AXI_SIZE_BYTES_1                                    3'b000
`define AXI_SIZE_BYTES_2                                    3'b001
`define AXI_SIZE_BYTES_4                                    3'b010
`define AXI_SIZE_BYTES_8                                    3'b011
`define AXI_SIZE_BYTES_16                                   3'b100
`define AXI_SIZE_BYTES_32                                   3'b101
`define AXI_SIZE_BYTES_64                                   3'b110
`define AXI_SIZE_BYTES_128                                  3'b111

module axi_rw # (
    parameter RW_DATA_WIDTH     = 128,
    parameter RW_ADDR_WIDTH     = 32,
    parameter AXI_DATA_WIDTH    = 64,
    parameter AXI_ID_WIDTH      = 4,
    parameter AXI_USER_WIDTH    = 1
)(
    input                               clock,
    input                               reset_n,
// original signal
	input                               rw_valid_i,
	output logic                        rw_ready_o,
    input                               rw_req_i,
    output logic [RW_DATA_WIDTH-1:0]      data_read_o,
    input  [RW_DATA_WIDTH-1:0]            data_write_i,
    input  [RW_ADDR_WIDTH-1:0]            rw_addr_i,
    input  [1:0]                        rw_size_i,
    output logic [1:0]                  rw_resp_o,
    input  [ RW_DATA_WIDTH/8-1 :0]                        rw_wmask_i,

    // Advanced eXtensible Interface
    axi4_if.Master                      Axi4_M
);
//------------------------------------------------------------------------------
//  (original) 
//------------------------------------------------------------------------------
    wire w_trans    = rw_req_i == `REQ_WRITE;
    wire r_trans    = rw_req_i == `REQ_READ;
    wire w_valid    = rw_valid_i & w_trans;
    wire r_valid    = rw_valid_i & r_trans;

    // handshake
    wire aw_hs      = Axi4_M.aw_valid & Axi4_M.aw_ready;
    wire w_hs       = Axi4_M.w_valid  & Axi4_M.w_ready ;
    wire b_hs       = Axi4_M.b_valid  & Axi4_M.b_ready ;
    wire ar_hs      = Axi4_M.ar_valid & Axi4_M.ar_ready;
    wire r_hs       = Axi4_M.r_valid  & Axi4_M.r_ready ;

    wire w_done     = w_hs & Axi4_M.w_last;
    wire r_done     = r_hs & Axi4_M.r_last;
    wire trans_done = w_trans ? b_hs : r_done;

    
    // ------------------State Machine------------------
    parameter [1:0] W_STATE_IDLE = 2'b00, W_STATE_ADDR = 2'b01, W_STATE_WRITE = 2'b10, W_STATE_RESP = 2'b11;
    parameter [1:0] R_STATE_IDLE = 2'b00, R_STATE_ADDR = 2'b01, R_STATE_READ  = 2'b10;

    reg [1:0] w_state, r_state;
    wire w_state_idle = w_state == W_STATE_IDLE, w_state_addr = w_state == W_STATE_ADDR, w_state_write = w_state == W_STATE_WRITE, w_state_resp = w_state == W_STATE_RESP;
    wire r_state_idle = r_state == R_STATE_IDLE, r_state_addr = r_state == R_STATE_ADDR, r_state_read  = r_state == R_STATE_READ;

    // Wirte State Machine
    always @(posedge clock) begin
        if (!reset_n) begin
            w_state <= W_STATE_IDLE;
        end
        else begin
            if (w_valid) begin
                case (w_state)
                    W_STATE_IDLE:               w_state <= W_STATE_ADDR;
                    W_STATE_ADDR:  if (aw_hs)   w_state <= W_STATE_WRITE;
                    W_STATE_WRITE: if (w_done)  w_state <= W_STATE_RESP;
                    W_STATE_RESP:  if (b_hs)    w_state <= W_STATE_IDLE;
                endcase
            end
        end
    end

    // Read State Machine
    always @(posedge clock) begin
        if (!reset_n) begin
            r_state <= R_STATE_IDLE;
        end
        else begin
            if (r_valid) begin
                case (r_state)
                    R_STATE_IDLE:               r_state <= R_STATE_ADDR;
                    R_STATE_ADDR: if (ar_hs)    r_state <= R_STATE_READ;
                    R_STATE_READ: if (r_done)   r_state <= R_STATE_IDLE;
                    default:;
                endcase
            end
        end
    end

    // ------------------Number of transmission------------------
    reg [7:0] len;
    //wire len_reset      = !reset_n | (w_trans & w_state_idle) | (r_trans & r_state_idle);
    //wire len_incr_en    = (len != axi_len) & (w_hs | r_hs);//axi_len = total write/read len
    always @(posedge clock) begin
        if (!reset_n) begin
            len <= 0;
        end
        else if((w_trans & w_state_idle) | (r_trans & r_state_idle))begin
            len <= 0;
        end
        else if ((len != axi_len) & (w_hs | r_hs)) begin
            len <= len + 1;
        end
    end

    // ------------------Process Data------------------
    parameter ALIGNED_WIDTH = $clog2(AXI_DATA_WIDTH / 8);       // 3 4
    parameter OFFSET_WIDTH  = $clog2(AXI_DATA_WIDTH);           // 6    
    parameter AXI_SIZE      = $clog2(AXI_DATA_WIDTH / 8);       // 3
    parameter MASK_WIDTH    = AXI_DATA_WIDTH * 2;               // 128    
    parameter TRANS_LEN     = RW_DATA_WIDTH / AXI_DATA_WIDTH;   // 1
    parameter BLOCK_TRANS   = TRANS_LEN > 1 ? 1'b1 : 1'b0;      // 0

    wire size_b             = rw_size_i == `SIZE_B;//00
    wire size_h             = rw_size_i == `SIZE_H;//01
    wire size_w             = rw_size_i == `SIZE_W;//10
    wire size_d             = rw_size_i == `SIZE_D;//11

    wire [7:0] axi_len      = 8'b1;
    wire [2:0] axi_size     = AXI_SIZE[2:0];

    wire [AXI_ID_WIDTH-1:0] axi_id              = {AXI_ID_WIDTH{1'b0}};
    //wire [AXI_USER_WIDTH-1:0] axi_user          = {AXI_USER_WIDTH{1'b0}};

    //reg rw_ready;
    //wire rw_ready_nxt = trans_done;
    //wire rw_ready_en      = trans_done | rw_ready;

    //wire [3 : 0] out_id_nxt = (Axi4_M.b_valid) ? Axi4_M.b_id : (Axi4_M.r_valid) ? Axi4_M.r_id : 0;

    always @(posedge clock) begin
        if (!reset_n) begin
            rw_ready_o <= 0;
        end
        else if (trans_done | rw_ready_o) begin
            rw_ready_o <= trans_done;
        end
    end

    always @(posedge clock) begin
        if (!reset_n) begin
            rw_resp_o <= 0;
        end
        else if (trans_done) begin
            rw_resp_o <= w_trans ? Axi4_M.b_resp : Axi4_M.r_resp;
        end
    end

//------------------------------------------------------------------------------
//  W/R Transactions 
//------------------------------------------------------------------------------
    // ------------------Write Transaction------------------
    // write addr channel:
    assign Axi4_M.aw_valid   = w_state_addr & w_valid;
    assign Axi4_M.aw_addr    = rw_addr_i;
    assign Axi4_M.aw_len     = axi_len;
    assign Axi4_M.aw_size    = axi_size;
    assign Axi4_M.aw_burst   = `AXI_BURST_TYPE_INCR;
    assign Axi4_M.aw_id      = axi_id;                                                                           // no use.


    //Write data channel signals
    assign Axi4_M.w_valid    = w_state_write;
    assign Axi4_M.w_last     = w_hs & (len == axi_len);

    assign Axi4_M.w_data  = w_last ? data_write_i[127:64] : data_write_i[63:0];
    assign Axi4_M.w_strb  = 8'b11111111;

    reg w_last;
    always @(posedge clock) begin
        w_last <= Axi4_M.w_valid;
    end

    //Write response channel signalss
    assign Axi4_M.b_ready    = w_state_resp & w_valid;

    // ------------------Read Transaction------------------
    // Read address channel signals
    assign Axi4_M.ar_valid   = r_state_addr & r_valid;
    assign Axi4_M.ar_addr    = rw_addr_i;
    assign Axi4_M.ar_id      = axi_id;
    assign Axi4_M.ar_len     = axi_len;
    assign Axi4_M.ar_size    = axi_size;
    assign Axi4_M.ar_burst   = `AXI_BURST_TYPE_INCR;


    // Read data channel signals
    assign Axi4_M.r_ready    = r_state_read;

    
    //dont care mask because no unaligned accesses
    always @(posedge clock) begin
        if (!reset_n) begin
            data_read_o <= 0;
        end
        else if (Axi4_M.r_valid & Axi4_M.r_ready) begin
            if (len == TRANS_LEN-1) begin
                data_read_o[TRANS_LEN*AXI_DATA_WIDTH-1:AXI_DATA_WIDTH] <= Axi4_M.r_data;
            end
            else begin
                data_read_o[AXI_DATA_WIDTH-1:0] <= Axi4_M.r_data;
            end
        end
    end

endmodule
