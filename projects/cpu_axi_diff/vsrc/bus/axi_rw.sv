
`include "defines.v"

// Burst types
`define AXI_BURST_TYPE_FIXED                                2'b00               //突发类型  FIFO
`define AXI_BURST_TYPE_INCR                                 2'b01               //ram  
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

`define AXI_SIZE_BYTES_1                                    3'b000                //突发宽度一个数据的宽度
`define AXI_SIZE_BYTES_2                                    3'b001
`define AXI_SIZE_BYTES_4                                    3'b010
`define AXI_SIZE_BYTES_8                                    3'b011
`define AXI_SIZE_BYTES_16                                   3'b100
`define AXI_SIZE_BYTES_32                                   3'b101
`define AXI_SIZE_BYTES_64                                   3'b110
`define AXI_SIZE_BYTES_128                                  3'b111


module axi_rw # (
    parameter RW_DATA_WIDTH     = 64,
    parameter RW_ADDR_WIDTH     = 32,
    parameter AXI_DATA_WIDTH    = 64,
    parameter AXI_ADDR_WIDTH    = 32,
    parameter AXI_ID_WIDTH      = 4,
    parameter AXI_STRB_WIDTH    = AXI_DATA_WIDTH/8,
    parameter AXI_USER_WIDTH    = 1
)(
    input                               clock,
    input                               reset,

	input                               rw_valid_i,         //IF&MEM输入信号
	output                              rw_ready_o,         //IF&MEM输入信号
    output reg [RW_DATA_WIDTH-1:0]      data_read_o,        //IF&MEM输入信号
    input  [RW_DATA_WIDTH-1:0]          rw_w_data_i,        //IF&MEM输入信号
    input  [RW_ADDR_WIDTH-1:0]          rw_addr_i,          //IF&MEM输入信号
    input  [7:0]                        rw_size_i,          //IF&MEM输入信号

    //IF interface (read only)
    input                                  m0_rw_valid_i,
    output                                 m0_rw_ready_o,
    input                                  m0_rw_req_i,//1:W_trans 0:R_trans
    output [RW_DATA_WIDTH-1:0]             m0_data_read_o,
    input  [AXI_DATA_WIDTH-1:0]            m0_rw_addr_i,
    input  [7:0]                           m0_rw_size_i,

    //MEM interface 
    input                                   m1_rw_valid_i,
    output                                  m1_rw_ready_o,
    input                                   m1_rw_req_i,
    output [RW_DATA_WIDTH-1:0]              m1_data_read_o,
    input  [RW_DATA_WIDTH-1:0]              m1_data_write_i,
    input  [7:0]                            m1_write_mask_i,
    input  [AXI_DATA_WIDTH-1:0]             m1_rw_addr_i,
    input  [7:0]                            m1_rw_size_i,

    // Advanced eXtensible Interface
    //address write channel
    input                               axi_aw_ready_i,              
    output                              axi_aw_valid_o,
    output [AXI_ADDR_WIDTH-1:0]         axi_aw_addr_o,
    output [2:0]                        axi_aw_prot_o,
    output [AXI_ID_WIDTH-1:0]           axi_aw_id_o,
    output [AXI_USER_WIDTH-1:0]         axi_aw_user_o,
    output [7:0]                        axi_aw_len_o,
    output [2:0]                        axi_aw_size_o,
    output [1:0]                        axi_aw_burst_o,
    output                              axi_aw_lock_o,
    output [3:0]                        axi_aw_cache_o,
    output [3:0]                        axi_aw_qos_o,
    output [3:0]                        axi_aw_region_o,
    //write data channel
    input                               axi_w_ready_i,                
    output                              axi_w_valid_o,
    output [AXI_DATA_WIDTH-1:0]         axi_w_data_o,
    output [AXI_DATA_WIDTH/8-1:0]       axi_w_strb_o, //byte mask
    output                              axi_w_last_o,
    output [AXI_USER_WIDTH-1:0]         axi_w_user_o,
    //write reposed channel
    output                              axi_b_ready_o,                
    input                               axi_b_valid_i,
    input  [1:0]                        axi_b_resp_i,                 
    input  [AXI_ID_WIDTH-1:0]           axi_b_id_i,
    input  [AXI_USER_WIDTH-1:0]         axi_b_user_i,
    //address read channel
    input                               axi_ar_ready_i,                
    output                              axi_ar_valid_o,
    output [AXI_ADDR_WIDTH-1:0]         axi_ar_addr_o,
    output [2:0]                        axi_ar_prot_o,
    output [AXI_ID_WIDTH-1:0]           axi_ar_id_o,
    output [AXI_USER_WIDTH-1:0]         axi_ar_user_o,
    output [7:0]                        axi_ar_len_o,
    output [2:0]                        axi_ar_size_o,
    output [1:0]                        axi_ar_burst_o,
    output                              axi_ar_lock_o,
    output [3:0]                        axi_ar_cache_o,
    output [3:0]                        axi_ar_qos_o,
    output [3:0]                        axi_ar_region_o,
    //read data channel
    output                              axi_r_ready_o,                 
    input                               axi_r_valid_i,                
    input  [1:0]                        axi_r_resp_i,
    input  [AXI_DATA_WIDTH-1:0]         axi_r_data_i,
    input                               axi_r_last_i,
    input  [AXI_ID_WIDTH-1:0]           axi_r_id_i,
    input  [AXI_USER_WIDTH-1:0]         axi_r_user_i
);
    localparam MASTER_0 = 1'b0, MASTER_1 = 1'b1;

    reg rw_req;
    reg rw_valid;
    reg [RW_DATA_WIDTH-1:0] rw_addr;
    reg [7:0] rw_size;
    reg [RW_DATA_WIDTH-1:0]  data_write_i;
    reg grant;
  
    //
    wire w_trans    =  rw_req == 1'b1;
    wire r_trans    =  rw_req == 1'b0;
    wire w_valid    =  rw_valid & w_trans;
    wire r_valid    =  rw_valid & r_trans;
  
    // handshake
    wire aw_hs      = axi_aw_ready_i & axi_aw_valid_o;
    wire w_hs       = axi_w_ready_i  & axi_w_valid_o;
    wire b_hs       = axi_b_ready_o  & axi_b_valid_i;
    wire ar_hs      = axi_ar_ready_i & axi_ar_valid_o;
    wire r_hs       = axi_r_ready_o  & axi_r_valid_i;
  
    wire r_done_for;                                          // r_done_for=1'b1: m0 read transaction done before m1 write transaction
    wire w_done     = w_hs & axi_w_last_o;
    wire r_done     = (r_hs & axi_r_last_i) | r_done_for;
    wire trans_done = w_trans ? b_hs : r_done;
    
    // ------------------State Machine------------------
    //TODO
    localparam [1:0] W_STATE_IDLE = 2'b00, W_STATE_ADDR = 2'b01, W_STATE_WRITE = 2'b10, W_STATE_RESP = 2'b11;
    localparam [1:0] R_STATE_IDLE = 2'b00, R_STATE_ADDR = 2'b01, R_STATE_READ  = 2'b10;
  
    reg [1:0] w_state, r_state;
    wire w_state_idle = (w_state == W_STATE_IDLE), w_state_addr = (w_state == W_STATE_ADDR), w_state_write = (w_state == W_STATE_WRITE), w_state_resp = (w_state == W_STATE_RESP);
    wire r_state_idle = (r_state == R_STATE_IDLE), r_state_addr = (r_state == R_STATE_ADDR), r_state_read  = (r_state == R_STATE_READ);

    // Wirte State Machine
    always @(posedge clock) begin
        if (reset) begin
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
            else begin
                    w_state <= W_STATE_IDLE;
            end
        end
    end
    // Read State Machine
    always @(posedge clock) begin
        if (reset) begin
            r_state <= R_STATE_IDLE;
        end
        else begin
            if (r_valid) begin
                case (r_state)
                    R_STATE_IDLE:               r_state <= R_STATE_ADDR;
                    R_STATE_ADDR: if (ar_hs)    r_state <= R_STATE_READ;
                    R_STATE_READ: if (r_done)   r_state <= R_STATE_IDLE;//read channel handshake and get the axi_r_last_i
                    default:;
                endcase
            end
        end
    end
    // process: m0 read transaction done before m1 write transaction
    //访存模块具有更高的优先级

    //取指过程中发生访存请求，则等到取指完成后再进行访存读操作
    //如果在取指过程中发生访存写请求，则读写同时进行，但需要等到访存结束后再给取指模块发送响应。
    reg reg_r_done;
    reg [AXI_ADDR_WIDTH-1:0] reg_r_adr;//打一拍，存住读地址
    always @(posedge clock) begin
        if(reset) begin
            reg_r_adr <= 'b0;
        end
        else if(ar_hs) begin
            reg_r_adr <= axi_ar_addr_o;//rw_addr_i
        end
        else begin
            reg_r_adr <= reg_r_adr;
        end
    end
    always @(posedge clock) begin
        if(reset) begin
            reg_r_done <= 1'b0;
        end
        else if(w_trans & r_done) begin
            reg_r_done <= 1'b1;
        end
        else if(~w_trans) begin
            reg_r_done <= 1'b0;
        end
    end
    assign r_done_for = (r_trans & reg_r_done); // m0 read transaction done before m1 write transaction
    /* ------------------Process Data------------------
    localparam ALIGNED_WIDTH = $clog2(AXI_DATA_WIDTH / 8);//3
    localparam OFFSET_WIDTH  = $clog2(AXI_DATA_WIDTH);//6
    localparam MASK_WIDTH    = AXI_DATA_WIDTH * 2;//128
    localparam TRANS_LEN     = RW_DATA_WIDTH / AXI_DATA_WIDTH;//1
    localparam BLOCK_TRANS   = TRANS_LEN > 1 ? 1'b1 : 1'b0;//0
  
    wire aligned            = BLOCK_TRANS | rw_addr[ALIGNED_WIDTH-1:0] == 0;
    wire size_b             = rw_size == `YSYX210366_SIZE_B;
    wire size_h             = rw_size == `YSYX210366_SIZE_H;
    wire size_w             = rw_size == `YSYX210366_SIZE_W;
    wire size_d             = rw_size == `YSYX210366_SIZE_D;
    wire [3:0] addr_op1     = {{4-ALIGNED_WIDTH{1'b0}}, rw_addr[ALIGNED_WIDTH-1:0]};
    wire [3:0] addr_op2     = ({4{size_b}} & {4'b0})
                                | ({4{size_h}} & {4'b1})
                                | ({4{size_w}} & {4'b11})
                                | ({4{size_d}} & {4'b111})
                                ;
    wire [3:0] addr_end     = addr_op1 + addr_op2;
    wire overstep           = addr_end[3:ALIGNED_WIDTH] != 0;
  
    wire [7:0] axi_len      = aligned ? TRANS_LEN - 1 : {{7{1'b0}}, overstep};
  
    wire [OFFSET_WIDTH-1:0] aligned_offset_l    = {{OFFSET_WIDTH-ALIGNED_WIDTH{1'b0}}, {rw_addr[ALIGNED_WIDTH-1:0]}} << 3;
    wire [OFFSET_WIDTH:0] aligned_offset_h      = AXI_DATA_WIDTH - aligned_offset_l;
    wire [MASK_WIDTH-1:0] mask                  = (({MASK_WIDTH{size_b}} & {{MASK_WIDTH-8{1'b0}}, 8'hff})
                                                    | ({MASK_WIDTH{size_h}} & {{MASK_WIDTH-16{1'b0}}, 16'hffff})
                                                    | ({MASK_WIDTH{size_w}} & {{MASK_WIDTH-32{1'b0}}, 32'hffffffff})
                                                    | ({MASK_WIDTH{size_d}} & {{MASK_WIDTH-64{1'b0}}, 64'hffffffff_ffffffff})
                                                    ) << aligned_offset_l;
    wire [AXI_DATA_WIDTH-1:0] mask_l            = mask[AXI_DATA_WIDTH-1:0];
    wire [AXI_DATA_WIDTH-1:0] mask_h            = mask[MASK_WIDTH-1:AXI_DATA_WIDTH];
    wire [AXI_ID_WIDTH-1:0] axi_id              = {AXI_ID_WIDTH{1'b0}};
  
    reg rw_ready;
    wire rw_ready_nxt = trans_done;
    wire rw_ready_en      = trans_done | rw_ready;
    always @(posedge clock) begin
        if (reset) begin
            rw_ready <= 0;
        end
        else if (rw_ready_en) begin
            rw_ready <= rw_ready_nxt;//表征一次传输结束
        end
    end*/

    // ------------------Number of transmission------------------
    reg [7:0] len;
    wire len_reset      = reset | (w_trans & w_state_idle) | (r_trans & r_state_idle);
    wire len_incr_en    = (len != axi_len) & (w_hs | r_hs);
    always @(posedge clock) begin
        if (len_reset) begin
            len <= 0;
        end
        else if (len_incr_en) begin
            len <= len + 1;
        end
    end
    // ------------------Write Transaction------------------
    parameter AXI_SIZE      = $clog2(AXI_DATA_WIDTH / 8); //==3
    wire [AXI_ID_WIDTH-1:0] axi_id              = {AXI_ID_WIDTH{1'b0}};
    wire [AXI_USER_WIDTH-1:0] axi_user          = {AXI_USER_WIDTH{1'b0}};
    wire [7:0] axi_len      =  8'b0 ;
    wire [2:0] axi_size     = AXI_SIZE[2:0];
    // 写地址通道  以下没有备注初始化信号的都可能是你需要产生和用到的
    assign axi_aw_valid_o   = w_state_addr;
    assign axi_aw_addr_o    = rw_addr_i;//读地址
    assign axi_aw_prot_o    = `AXI_PROT_UNPRIVILEGED_ACCESS | `AXI_PROT_SECURE_ACCESS | `AXI_PROT_DATA_ACCESS;  //初始化信号即可
    assign axi_aw_id_o      = axi_id;                                                                           //初始化信号即可
    assign axi_aw_user_o    = axi_user;                                                                         //初始化信号即可
    assign axi_aw_len_o     = axi_len;//读个数
    assign axi_aw_size_o    = axi_size;//读字节数
    assign axi_aw_burst_o   = `AXI_BURST_TYPE_INCR;                                                             
    assign axi_aw_lock_o    = 1'b0;                                                                             //初始化信号即可
    assign axi_aw_cache_o   = `AXI_AWCACHE_WRITE_BACK_READ_AND_WRITE_ALLOCATE;                                  //初始化信号即可
    assign axi_aw_qos_o     = 4'h0;                                                                             //初始化信号即可
    assign axi_aw_region_o  = 4'h0;                                                                             //初始化信号即可

    // 写数据通道
    assign axi_w_valid_o    = w_state_write;
    assign axi_w_data_o     = rw_w_data_i ;
    assign axi_w_strb_o     = rw_size_i;
    assign axi_w_last_o     = 1'b0;
    assign axi_w_user_o     = axi_user;                                                                         //初始化信号即可

    // 写应答通道
    assign axi_b_ready_o    = w_state_resp;

    // ------------------Read Transaction------------------

    // Read address channel signals
    assign axi_ar_valid_o   = r_state_addr;
    assign axi_ar_addr_o    = rw_addr_i;
    assign axi_ar_prot_o    = `AXI_PROT_UNPRIVILEGED_ACCESS | `AXI_PROT_SECURE_ACCESS | `AXI_PROT_DATA_ACCESS;  //初始化信号即可
    assign axi_ar_id_o      = axi_id;                                                                           //初始化信号即可                        
    assign axi_ar_user_o    = axi_user;                                                                         //初始化信号即可
    assign axi_ar_len_o     = axi_len;                                                                          
    assign axi_ar_size_o    = axi_size;
    assign axi_ar_burst_o   = `AXI_BURST_TYPE_INCR;
    assign axi_ar_lock_o    = 1'b0;                                                                             //初始化信号即可
    assign axi_ar_cache_o   = `AXI_ARCACHE_NORMAL_NON_CACHEABLE_NON_BUFFERABLE;                                 //初始化信号即可
    assign axi_ar_qos_o     = 4'h0;                                                                             //初始化信号即可

    // Read data channel signals
    assign axi_r_ready_o    = r_state_read;

    wire [AXI_DATA_WIDTH-1:0] axi_r_data_l  = (w_trans & r_done)? {32'b0, axi_r_data_i[31:0]} : (axi_r_data_i & mask_l) >> aligned_offset_l;
    wire [AXI_DATA_WIDTH-1:0] axi_r_data_h  = (axi_r_data_i & mask_h) << aligned_offset_h;

    reg [RW_DATA_WIDTH-1:0]        data_read_o;

    generate
      genvar i;
        for (i = 0; i < TRANS_LEN; i = i+1) begin:DATA_READ_REG_LOOP
            always @(posedge clock) begin
                if (reset) begin
                    data_read_o[i*AXI_DATA_WIDTH+:AXI_DATA_WIDTH] <= 0;
                end
                else if (axi_r_ready_o & axi_r_valid_i) begin
                    if (~aligned & overstep) begin
                        if (len[0]) begin
                            data_read_o[AXI_DATA_WIDTH-1:0] <= data_read_o[AXI_DATA_WIDTH-1:0] | axi_r_data_h;
                        end
                        else begin
                            data_read_o[AXI_DATA_WIDTH-1:0] <= axi_r_data_l;
                        end
                    end
                    else if (len == i) begin
                        data_read_o[i*AXI_DATA_WIDTH+:AXI_DATA_WIDTH] <= axi_r_data_l;
                    end
                end
            end
        end
    endgenerate 
    //--------------------------Arbitration------------------------------------------
    //arbitrate m1 > m0
    always @(posedge clock) begin
        if(r_state == R_STATE_IDLE)
            grant <= (m1_rw_valid_i)? MASTER_1 : (m0_rw_valid_i)? MASTER_0 : 'b0;
        else if(w_state == W_STATE_ADDR)
            grant <= (m1_rw_valid_i)? MASTER_1 : 'b0;
    end
    always @(*) begin
        rw_req = 1'b0;
        rw_valid = 1'b0;
        rw_addr = 'b0;
        rw_size = 'b0;
        data_write_i = 'b0;
  
        if(m1_rw_valid_i==1'b1) begin
            rw_req = m1_rw_req_i;
            rw_valid = m1_rw_valid_i;
            rw_addr = m1_rw_addr_i;
            rw_size = m1_rw_size_i;
            data_write_i = m1_data_write_i;
        end
        else if(m0_rw_valid_i) begin
            rw_req = m0_rw_req_i;
            rw_valid = m0_rw_valid_i;
            rw_addr = m0_rw_addr_i;
            rw_size = m0_rw_size_i;
        end
        
    end
    assign m1_rw_ready_o = (m1_rw_valid_i && grant == MASTER_1)? rw_ready : 1'b0;          
    assign m0_rw_ready_o = (m1_rw_valid_i && grant == MASTER_1)? 1'b0 : rw_ready;
    assign m1_data_read_o = m1_rw_valid_i? data_read_o : 'b0;
    assign m0_data_read_o = m1_rw_valid_i? 'b0 : data_read_o;  //inst 

endmodule

/*
    ysyx_210366_AXI_RW ysyx_210366_AXI_RW(
            .clock                          (clock),
            .reset                          (reset),

            .m0_rw_valid_i                  (if_valid),
            .m0_rw_ready_o                  (if_ready),
            .m0_rw_req_i                    (if_req),
            .m0_data_read_o                 (if_data_read),
            .m0_rw_addr_i                   (if_addr),
            .m0_rw_size_i                   (if_size),

            .m1_rw_valid_i                  (mem_valid),
            .m1_rw_ready_o                  (mem_ready),
            .m1_rw_req_i                    (mem_req),
            .m1_data_read_o                 (mem_data_read),
            .m1_data_write_i                (mem_data_write),
            .m1_write_mask_i                (mem_wmask),
            .m1_rw_addr_i                   (mem_addr),
            .m1_rw_size_i                   (mem_size),

            .axi_aw_ready_i                 (aw_ready),
            .axi_aw_valid_o                 (aw_valid),
            .axi_aw_addr_o                  (aw_addr),
            .axi_aw_id_o                    (aw_id),
            .axi_aw_len_o                   (aw_len),
            .axi_aw_size_o                  (aw_size),
            .axi_aw_burst_o                 (aw_burst),

            .axi_w_ready_i                  (w_ready),
            .axi_w_valid_o                  (w_valid),
            .axi_w_data_o                   (w_data),
            .axi_w_strb_o                   (w_strb),
            .axi_w_last_o                   (w_last),
            
            .axi_b_ready_o                  (b_ready),
            .axi_b_valid_i                  (b_valid),
            .axi_b_resp_i                   (b_resp),
            .axi_b_id_i                     (b_id),

            .axi_ar_ready_i                 (ar_ready),
            .axi_ar_valid_o                 (ar_valid),
            .axi_ar_addr_o                  (ar_addr),
            .axi_ar_id_o                    (ar_id),
            .axi_ar_len_o                   (ar_len),
            .axi_ar_size_o                  (ar_size),
            .axi_ar_burst_o                 (ar_burst),
            
            .axi_r_ready_o                  (r_ready),
            .axi_r_valid_i                  (r_valid),
            .axi_r_resp_i                   (r_resp),
            .axi_r_data_i                   (r_data),
            .axi_r_last_i                   (r_last),
            .axi_r_id_i                     (r_id)
    );*/