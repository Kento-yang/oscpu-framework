//2022.8.15 icache V1.0
//YCT
//例化两个SRAM 128bits, one cache line store 4 inst. Depth = 64*2 = 128
//------------------------------------------------------------------------------
//              <---if_ic_valid_i----
//   I-CACHE    ----if_ic_ready_o--->    IF_STAGE
//              ----if_ic_rdata_o--->
//              <----if_ic_addr_i----
//------------------------------------------------------------------------------
`include "rvseed_defines.sv"
module icache #(
    parameter CACHE_LINE_WIDTH = 128, 
    parameter CACHE_LINE_DEPTH = 128, 
    parameter CACHE_ADDR_WIDTH = 7,
    parameter I_TAG = 21,
    parameter I_INDEX = 7,
    parameter I_OFFSET = 4
)(
    input logic                          clk,
    input logic                          rst_n,
    input logic   [`PC_WIDTH-1:0]        if_pc,
//core---icache
    input                                if_ic_valid_i                   ,
    output                               if_ic_ready_o_r                ,
    output        [`AXI_DATA_WIDTH-1:0]  if_ic_rdata_o                   ,
    input logic   [`AXI_ADDR_WIDTH-1:0]  if_ic_addr_i                    ,
    input             [   1:0]           if_ic_size                      ,
    output            [   1:0]           if_ic_resp                      ,

//icache---arbiter
    output                               arb_ic_valid_o_and_r               ,
    input                                arb_ic_ready_i                  ,
    input        [ CACHE_LINE_WIDTH-1: 0]   arb_ic_rdata_i               ,
    output logic [`AXI_ADDR_WIDTH-1:0]   arb_ic_addr_o                   ,
    output             [   1:0]          arb_ic_size                     ,
    input              [   1:0]          arb_ic_resp                     ,//读响应信号

    output logic                         hit,
    output logic                         hit_r,
    output logic                         hit_delay_o
);
    //size/resp pass icache.
    assign arb_ic_size = `SIZE_D;//double word
    assign if_ic_resp = arb_ic_resp;

    localparam RAM_WIDTH = 128;
    localparam RAM_DEPTH = 64;

    localparam IDLE    = 3'b000, 
               LOOK_UP = 3'b001, 
               MISS    = 3'b010, 
               REPLACE = 3'b011, //替换，等待axi握手成功开始重新填充
               REFILL  = 3'b100; //填充tag data valid.
    logic [2:0] state, next_state;
    
    
    reg [I_TAG:0] way0_tag [0:127];//{valid, tag} 1+21=22bit
    reg [I_TAG:0] way1_tag [0:127];//{valid, tag} 1+21=22bit
    
    wire [I_TAG:0] way0_addr0_tag = way0_tag[0][I_TAG:0];


    wire [I_TAG-1:0]    if_addr_tag     = if_pc[31:11];//addr 64bit, only low 32bit valid fot fetch inst
    wire [I_INDEX-1:0]  if_addr_index   = if_pc[10:4];
    wire [I_OFFSET-1:0] if_addr_offset  = if_pc[I_OFFSET-1:0];
    logic [I_INDEX-1:0] if_addr_index_r;
    //while hit but
    wire  index_change = (if_addr_index_r != if_addr_index);
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            if_addr_index_r <= 0;
        end else begin
            if_addr_index_r <= if_addr_index;
        end
    end
 
    logic hit_way0, hit_way1;
    //logic hit, hit_r;
    assign hit_way0 = ({1'b1, if_addr_tag } == way0_tag[if_addr_index] ) ? 1 : 0 ; //{valid,tag}
    assign hit_way1 = ({1'b1, if_addr_tag } == way1_tag[if_addr_index] ) ? 1 : 0 ; //{valid,tag}
    assign hit = hit_way0 | hit_way1;
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            hit_r <= hit;
        end else begin
            hit_r <= hit;
        end
    end

    assign hit_delay_o = hit_r & hit;//align with sram rd

    //logic if_ic_ready_o;
    wire if_read_hs = if_ic_valid_i & if_ic_ready_o;
    wire axi_read_hs = arb_ic_valid_o & arb_ic_ready_i;

    
//------------------------------------------------------------------------------
//  STATE MACHINE           
//------------------------------------------------------------------------------

//1.状态跳变
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end
//2.组合逻辑进行状态判断
    always_comb begin
        case(state)
        IDLE:   if(if_ic_valid_i)
                    next_state = LOOK_UP;
                else
                    next_state = IDLE;

        LOOK_UP:if(hit & if_ic_valid_i)
                    next_state = LOOK_UP;
                else if(hit & !if_ic_valid_i)
                    next_state = IDLE;
                else 
                    next_state = MISS;

        MISS:       next_state = REPLACE;

        REPLACE:if(axi_read_hs)
                    next_state = REFILL;
                else
                    next_state = REPLACE;

        REFILL: if(hit & if_ic_valid_i)
                    next_state = IDLE;
                else
                    next_state = REFILL;

        default:    next_state = IDLE;
        endcase 
    end
//3.时序逻辑输出
    integer i;
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            if_ic_ready_o <= 0;
            arb_ic_valid_o <= 0;
            arb_ic_addr_o <= 0;
            for(i = 0; i < 64; i++)begin
                way0_tag[i][I_TAG]<= 'b0;
                way1_tag[i][I_TAG]<= 'b0;
            end
            for(i = 64; i < CACHE_LINE_DEPTH; i++)begin
                way0_tag[i][I_TAG]<= 'b0;
                way1_tag[i][I_TAG]<= 'b0;
            end
            way0_cen <= 1;
            way0_wen <= 1;
            way1_cen <= 1;
            way1_wen <= 1;
        end
        else begin
            case(next_state)
                IDLE: begin
                      if_ic_ready_o <= 0;
                      arb_ic_valid_o <= 0;
                    /*if(hit_way0) begin//way 0 output
                        way0_cen <= 0;
                        way0_wen <= 1;
                        way1_cen <= 0;
                        way1_wen <= 1;
                    end
                    else if(hit_way1)begin//way1 output
                        way0_cen <= 0;
                        way0_wen <= 1;
                        way1_cen <= 0;
                        way1_wen <= 1;
                    end
                    else begin
                        way0_cen <= 1;
                        way0_wen <= 1;
                        way1_cen <= 1;
                        way1_wen <= 1;
                    end*/
                end
                LOOK_UP:begin
                    if(hit_way0) begin//way 0 output
                        if_ic_ready_o <= 1;
                        way0_cen <= 0;
                        way0_wen <= 1;
                        way1_cen <= 0;
                        way1_wen <= 1;
                    end
                    else if(hit_way1)begin//way1 output
                        if_ic_ready_o <= 1;
                        way0_cen <= 0;
                        way0_wen <= 1;
                        way1_cen <= 0;
                        way1_wen <= 1;
                    end
                    else begin
                        if_ic_ready_o <= 0;
                        way0_cen <= 1;
                        way0_wen <= 1;
                        way1_cen <= 1;
                        way1_wen <= 1;
                        arb_ic_valid_o <= 0;
                    end
                end
                MISS:if_ic_ready_o <= 0;
                REPLACE:begin
                        arb_ic_valid_o <= 1;
                        arb_ic_addr_o <= {if_ic_addr_i[`AXI_ADDR_WIDTH-1:4],4'b0};//0x18 axi_rd error ! 0x10 inst need first instead of 0x18
                        if_ic_ready_o <= 0;
                end
                REFILL:begin
                    arb_ic_valid_o <= 0;
                    if(!age)begin//LRU refill use age.
                        way0_tag[if_addr_index][I_TAG:0] <= {1'b1,if_addr_tag};
                        way0_wdata <= arb_ic_rdata_i;
                        way0_cen <= 0;
                        way0_wen <= 0;
                    end
                    else begin
                        way1_tag[if_addr_index][I_TAG:0] <= {1'b1,if_addr_tag};
                        way1_wdata <= arb_ic_rdata_i;
                        way1_cen <= 0;
                        way1_wen <= 0;
                    end              
                end
                default:begin 
                    if_ic_ready_o <= 0;
                    arb_ic_valid_o <= 0;
                    arb_ic_addr_o <= 0;
                    way0_cen <= 1;
                    way0_wen <= 1;
                    way1_cen <= 1;
                    way1_wen <= 1;
                end
            endcase
        end
    end
    // delay becausd of sram delay
    logic if_read_hs_r;
    logic arb_ic_valid_o, arb_ic_valid_o_r1, arb_ic_valid_o_r2;
    logic if_ic_ready_o,if_ic_ready_o_r1;
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
           //if_ic_ready_o_r <= 0;
            arb_ic_valid_o_r1 <= 0 ;
            if_ic_ready_o_r1  <= 0 ;
            arb_ic_valid_o_r2 <= 0 ;
        end else begin
            //if_ic_ready_o_r <= if_ic_ready_o;   
            arb_ic_valid_o_r1 <= arb_ic_valid_o;//align with jump_pc need delay 2  cycle
            arb_ic_valid_o_r2 <= arb_ic_valid_o_r1;
            if_ic_ready_o_r1 <= if_ic_ready_o;  //align with sram rdata.
        end
    end

    assign if_ic_ready_o_r = if_ic_ready_o_r1 && !index_change;
    assign arb_ic_valid_o_and_r = arb_ic_valid_o & arb_ic_valid_o_r1 & arb_ic_valid_o_r2;
                   
//3.1 TAG equal! hit the cache and return the inst according the OFFSET.（valid == 1）
    always_comb begin
        if(hit_way0)
            case(if_pc[I_OFFSET-1:I_OFFSET-2])
                2'b00: if_ic_rdata_o = way0_rdata[63:0];
                2'b01: if_ic_rdata_o = way0_rdata[95:32];
                2'b10: if_ic_rdata_o = way0_rdata[127:64];
                2'b11: if_ic_rdata_o = {{32{1'b0}}, way0_rdata[127:96]};
                default:;
            endcase
        else if(hit_way1)
            case(if_pc[I_OFFSET-1:I_OFFSET-2])
                2'b00: if_ic_rdata_o = way1_rdata[63:0];
                2'b01: if_ic_rdata_o = way1_rdata[95:32];
                2'b10: if_ic_rdata_o = way1_rdata[127:64];
                2'b11: if_ic_rdata_o = {{32{1'b0}}, way1_rdata[127:96]};
                default:;
            endcase
        else
            if_ic_rdata_o = 64'b0;
    end
//LRU replace
    logic age;//age=1 replace way 0,age=0 replace 1
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)
            age <= 0;
        else if(hit_way0)
            age <= 1;// way 1 recently free
        else if(hit_way1)
            age <= 0;// way 0 recently free
    end
    
//3.2 TAG unequal/valid == 0 , miss the cache line and fire AXI read.

//5. waiting for AXI_RDATA, replace cache line base the INDEX, pull valid high.

//6. the same with operation 3.

//2-WAY CACHE use 128bit*64 SRAM
    logic [CACHE_LINE_WIDTH-1:0]     way0_rdata, way1_rdata;
    logic                            way0_cen,   way1_cen  ;
    logic                            way0_wen,   way1_wen  ;
    //logic [CACHE_ADDR_WIDTH-1:0]     way0_addr,  way1_addr ;
    logic [CACHE_LINE_WIDTH-1:0]     way0_wdata, way1_wdata;
    
icache_ram u_way0(.Q( way0_rdata), .CLK (clk), .CEN (way0_cen), .WEN (way0_wen ), .A(if_addr_index), .D(way0_wdata) );
icache_ram u_way1(.Q( way1_rdata), .CLK (clk), .CEN (way1_cen), .WEN (way1_wen ), .A(if_addr_index), .D(way1_wdata) );


endmodule