`include "rvseed_defines.sv"
module dcache #(
    parameter CACHE_LINE_WIDTH = 128, 
    parameter CACHE_LINE_DEPTH = 128, 
    parameter CACHE_ADDR_WIDTH = 7,
    parameter D_TAG = 54,
    parameter D_INDEX = 7,
    parameter D_OFFSET = 4
)(
    input logic                             clk                             ,
    input logic                             rst_n                           ,
//MEM INTTERFACE
    input                                   mem_dc_valid_i                  ,
    output                                  mem_dc_ready_o                  ,
    input                                   mem_dc_rw_req_i                 ,//1:store 0:load
    output            [  63:0]              mem_dc_data_read_o              ,
    input             [  63:0]              mem_dc_data_write_i             ,
    input             [`AXI_ADDR_WIDTH-1:0] mem_dc_addr_i                   ,
    input             [   1:0]              mem_dc_size_i                   ,
    output            [   1:0]              mem_dc_resp_o                   ,
    input             [   7:0]              mem_dc_wmask_i                  ,

//dcache---arbiter
    output                                  arb_dc_valid_o                  ,
    input                                   arb_dc_ready_i                  ,
    output                                  arb_dc_rw_req_o                 ,
    input           [CACHE_LINE_WIDTH-1:0]  arb_dc_data_read_i              ,
    output          [CACHE_LINE_WIDTH-1:0]  arb_dc_data_write_o             ,
    output          [`AXI_ADDR_WIDTH-1:0]   arb_dc_addr_o                   ,
    output             [   1:0]             arb_dc_size_o                   ,
    input              [   1:0]             arb_dc_resp_i                   ,
    output             [   7:0]             arb_dc_wmask_o                  
);
    logic [CACHE_LINE_WIDTH-1:0] rpl_cacheline_buf0, rpl_cacheline_buf1;
    assign rpl_cacheline_buf0 = way0_rdata;
    assign rpl_cacheline_buf1 = way1_rdata;

    logic [1:0] rpl_en;
    //assign rpl_en = (way0_tag[mem_addr_index][D_TAG:D_TAG-1] == 2'b11) || (way1_tag[mem_addr_index][D_TAG:D_TAG-1] == 2'b11);
//through dcache
    assign arb_dc_size_o = mem_dc_size_i;//mem --> axi    
    assign mem_dc_resp_o = arb_dc_resp_i;//axi -->mem    
    assign arb_dc_wmask_o = mem_dc_wmask_i;
    /*logic [63:0] way_wmask;
  always_comb begin
    case (mem_dc_wmask_i)
        8'b0000_0001: way_wmask = 64'h0000_0000_0000_00FF;
        8'b0000_0011: way_wmask = 64'h0000_0000_0000_FFFF;
        8'b0000_1111: way_wmask = 64'h0000_0000_FFFF_FFFF;
        8'b1111_1111: way_wmask = 64'hFFFF_FFFF_FFFF_FFFF;
      default:  way_wmask = 64'b0;
    endcase
  end*/
    localparam RAM_WIDTH = 128, RAM_DEPTH = 64;

    localparam IDLE    = 3'b000,
               LOOK_UP = 3'b001,
               WRCACHE = 3'b010,
               READY   = 3'b011,
               MISS    = 3'b100,
               REPLACE = 3'b101,
               REFILL  = 3'b110;
    logic [2:0] state, next_state;
        
    reg [D_TAG:0] way0_tag [0:127];//{dirty,valid, tag} 1+1+53=55bit
    reg [D_TAG:0] way1_tag [0:127];//{dirty,valid, tag} 1+1+53=55bit
    
    wire [D_TAG-2:0]    mem_addr_tag     = mem_dc_addr_i[63:11];
    wire [D_INDEX-1:0]  mem_addr_index   = mem_dc_addr_i[10:4];
    wire [D_OFFSET-1:0] mem_addr_offset  = mem_dc_addr_i[D_OFFSET-1:0];

    /*logic [D_INDEX-1:0] mem_addr_index_r;
    //while hit but
    wire  index_change = (mem_addr_index_r != mem_addr_index);
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            mem_addr_index_r <= 0;
        end else begin
            mem_addr_index_r <= mem_addr_index;
        end
    end*/
 
    logic hit_way0, hit_way1;
    logic hit;
    assign hit_way0 = ({1'b1, mem_addr_tag} == way0_tag[mem_addr_index][D_TAG-1 :0] ) ? 1 : 0 ; //dirty,{valid,tag}
    assign hit_way1 = ({1'b1, mem_addr_tag} == way1_tag[mem_addr_index][D_TAG-1 :0] ) ? 1 : 0 ; //dirty,{valid,tag}
    assign hit = hit_way0 | hit_way1;

    //logic if_ic_ready_o;
    wire mem_dc_hs = mem_dc_valid_i & mem_dc_ready_o;
    wire axi_arb_hs = arb_dc_valid_o & arb_dc_ready_i;

//------------------------------------------------------------------------------
//  STATE MACHINE           
//------------------------------------------------------------------------------
 /*注意：只有在cache line替换时，dirty=1才需要写入下级存储!!(可以存储到dirty的cache line中)
 0.初始，mem请求（传递valid addr req size resp） req为写需要传递wdata，wmask
 1.查询，若hit（根据index寻址，且对应的valid为高）且valid=1则
        (1)读出对应cache line 128bit ,
        (2)根据req类型：LD则直接跳转至拉高ready态，;
                       为ST则根据offset替换对应bit，准备好数据并跳转写回
    缺失则跳转.
 2.写回，将并换掉了对应offset bit的cache line, 重新写入cache中，并置高dirty bit.跳回写回态.
 3.拉高ready .此状态专门用于拉高ready 与从sram读出数据是同步的。LD则直接输出对应offset数据.ST则直接输出ready表示完成存储.
 4.缺失，进行总线访问（arb_valid置高），等待返回对应cache line数据（arb-dc 握手成功跳转），此时读出要写入的way的数据，替换数据（如果有的话）
 5.替换，若原index对应cache line V=D=1，则需要写回（arb_valid再次置高，进行总线存储）。否则直接丢弃。
 6.填充，若需要写回，则等待写回完成，进行新cache line填充.不需要写回则直接填充。填充完毕之后hit会置高，回到初始状态。   
*/
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
        IDLE:   if(mem_dc_valid_i)
                    next_state = LOOK_UP;
                else
                    next_state = IDLE;

        LOOK_UP:if(hit && mem_dc_valid_i && mem_dc_rw_req_i)//store
                    next_state = WRCACHE;
                else if(hit && mem_dc_valid_i && !mem_dc_rw_req_i)
                    next_state = READY;
                else if(!hit && mem_dc_valid_i)
                    next_state = MISS;
                else
                    next_state = IDLE;

        WRCACHE:    next_state = READY;

        READY:  //if(hit && mem_dc_valid_i )//store
                //    next_state = LOOK_UP;
                //else 
                    next_state = IDLE;

        MISS:   if(axi_arb_hs)
                    next_state = REPLACE;
                else 
                    next_state = MISS;

        REPLACE:if(axi_arb_hs || !rpl_en[1])    //if replace need wait 1 cycle, or 
                    next_state = REFILL;
                else 
                    next_state = REPLACE;
        REFILL: if(hit & mem_dc_valid_i)
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
            mem_dc_ready_o <= 0;
            arb_dc_valid_o <= 0;
            arb_dc_addr_o <= 0;
            //arb_dc_rw_req_o <= 0;
            for(i = 0; i < 64; i++)begin
                way0_tag[i][D_TAG: D_TAG-1]<= 2'b00;
                way1_tag[i][D_TAG: D_TAG-1]<= 2'b00;
            end
            for(i = 64; i < CACHE_LINE_DEPTH; i++)begin
                way0_tag[i][D_TAG: D_TAG-1]<= 2'b00;
                way1_tag[i][D_TAG: D_TAG-1]<= 2'b00;
            end
            way0_cen <= 1;
            way0_wen <= 1;
            way1_cen <= 1;
            way1_wen <= 1;
            rpl_en <= 2'b00;
        end
        else begin
            case(next_state)
                IDLE: begin
                    mem_dc_ready_o <= 0;
                    arb_dc_valid_o <= 0;
                    arb_dc_rw_req_o <= 1'b0;//read
                    way0_cen <= 0; way0_wen <= 1;
                    way1_cen <= 0; way1_wen <= 1;
                end
                LOOK_UP:begin
                    arb_dc_rw_req_o <= 1'b0;//read
                    if(hit_way0) begin//read way 0 
                        mem_dc_ready_o <= 0;
                        way0_cen <= 0; way0_wen <= 1;
                        way1_cen <= 0; way1_wen <= 1;
                    end
                    else if(hit_way1)begin//read way1 
                        mem_dc_ready_o <= 0;
                        way0_cen <= 0; way0_wen <= 1;
                        way1_cen <= 0; way1_wen <= 1;
                    end
                    else begin
                        mem_dc_ready_o <= 0;
                        way0_cen <= 1; way0_wen <= 1;
                        way1_cen <= 1; way1_wen <= 1;
                        arb_dc_valid_o <= 0;
                    end
                end
                WRCACHE:begin//
                    way0_wdata <= 128'b0;
                    way1_wdata <= 128'b0;
//==================write way0========================
                    if(hit_way0) begin
                        way0_tag[mem_addr_index][D_TAG] <= 1;
                        way0_cen <= 0; way0_wen <= 0;
                        way1_cen <= 0; way1_wen <= 1;
                        if(mem_dc_wmask_i == 8'b1111_1111)begin
                            case(mem_addr_offset[D_OFFSET-1:0])
                                4'b0000: way0_wdata <= {rpl_cacheline_buf0[127:64],  (mem_dc_data_write_i[63:0])};
                                4'b0001: way0_wdata <= {rpl_cacheline_buf0[127:72],  (mem_dc_data_write_i[63:0]), rpl_cacheline_buf0[7:0]};
                                4'b0010: way0_wdata <= {rpl_cacheline_buf0[127:80],  (mem_dc_data_write_i[63:0]), rpl_cacheline_buf0[15:0]};
                                4'b0011: way0_wdata <= {rpl_cacheline_buf0[127:88],  (mem_dc_data_write_i[63:0]), rpl_cacheline_buf0[23:0]};
                                4'b0100: way0_wdata <= {rpl_cacheline_buf0[127:96],  (mem_dc_data_write_i[63:0]), rpl_cacheline_buf0[31:0]};
                                4'b0101: way0_wdata <= {rpl_cacheline_buf0[127:104], (mem_dc_data_write_i[63:0]), rpl_cacheline_buf0[39:0]};
                                4'b0110: way0_wdata <= {rpl_cacheline_buf0[127:112], (mem_dc_data_write_i[63:0]), rpl_cacheline_buf0[47:0]};
                                4'b0111: way0_wdata <= {rpl_cacheline_buf0[127:120], (mem_dc_data_write_i[63:0]), rpl_cacheline_buf0[55:0]};
                                4'b1000: way0_wdata <= {(mem_dc_data_write_i[63:0]), rpl_cacheline_buf0[63:0]};
                                4'b1001: way0_wdata <= {(mem_dc_data_write_i[55:0]), rpl_cacheline_buf0[71:0]};
                                4'b1010: way0_wdata <= {(mem_dc_data_write_i[47:0]), rpl_cacheline_buf0[79:0]};
                                4'b1011: way0_wdata <= {(mem_dc_data_write_i[39:0]), rpl_cacheline_buf0[87:0]};
                                4'b1100: way0_wdata <= {(mem_dc_data_write_i[31:0]), rpl_cacheline_buf0[95:0]};
                                4'b1101: way0_wdata <= {(mem_dc_data_write_i[23:0]), rpl_cacheline_buf0[103:0]};
                                4'b1110: way0_wdata <= {(mem_dc_data_write_i[15:0]), rpl_cacheline_buf0[111:0]};
                                4'b1111: way0_wdata <= {(mem_dc_data_write_i[7:0] ), rpl_cacheline_buf0[119:0]};
                                default: ;
                            endcase
                            end
                        else if(mem_dc_wmask_i == 8'b0000_1111)begin
                            case(mem_addr_offset[D_OFFSET-1:0])
                                4'b0000: way0_wdata <= {rpl_cacheline_buf0[127:32],  (mem_dc_data_write_i[31:0])};
                                4'b0001: way0_wdata <= {rpl_cacheline_buf0[127:40],  (mem_dc_data_write_i[31:0]), rpl_cacheline_buf0[7:0]};
                                4'b0010: way0_wdata <= {rpl_cacheline_buf0[127:48],  (mem_dc_data_write_i[31:0]), rpl_cacheline_buf0[15:0]};
                                4'b0011: way0_wdata <= {rpl_cacheline_buf0[127:56],  (mem_dc_data_write_i[31:0]), rpl_cacheline_buf0[23:0]};
                                4'b0100: way0_wdata <= {rpl_cacheline_buf0[127:64],  (mem_dc_data_write_i[31:0]), rpl_cacheline_buf0[31:0]};
                                4'b0101: way0_wdata <= {rpl_cacheline_buf0[127:72],  (mem_dc_data_write_i[31:0]), rpl_cacheline_buf0[39:0]};
                                4'b0110: way0_wdata <= {rpl_cacheline_buf0[127:80],  (mem_dc_data_write_i[31:0]), rpl_cacheline_buf0[47:0]};
                                4'b0111: way0_wdata <= {rpl_cacheline_buf0[127:88],  (mem_dc_data_write_i[31:0]), rpl_cacheline_buf0[55:0]};
                                4'b1000: way0_wdata <= {rpl_cacheline_buf0[127:96],  (mem_dc_data_write_i[31:0]), rpl_cacheline_buf0[63:0]};
                                4'b1001: way0_wdata <= {rpl_cacheline_buf0[127:104], (mem_dc_data_write_i[31:0]), rpl_cacheline_buf0[71:0]};
                                4'b1010: way0_wdata <= {rpl_cacheline_buf0[127:112], (mem_dc_data_write_i[31:0]), rpl_cacheline_buf0[79:0]};
                                4'b1011: way0_wdata <= {rpl_cacheline_buf0[127:120], (mem_dc_data_write_i[31:0]), rpl_cacheline_buf0[87:0]};
                                4'b1100: way0_wdata <= {(mem_dc_data_write_i[31:0]), rpl_cacheline_buf0[95:0]};
                                4'b1101: way0_wdata <= {(mem_dc_data_write_i[23:0]), rpl_cacheline_buf0[103:0]};
                                4'b1110: way0_wdata <= {(mem_dc_data_write_i[15:0]), rpl_cacheline_buf0[111:0]};
                                4'b1111: way0_wdata <= {(mem_dc_data_write_i[7:0] ), rpl_cacheline_buf0[119:0]};
                                default: ;
                            endcase
                            end                       
                        else if(mem_dc_wmask_i == 8'b0000_0011)begin
                            case(mem_addr_offset[D_OFFSET-1:0])
                                4'b0000: way0_wdata <= {rpl_cacheline_buf0[127:16],  (mem_dc_data_write_i[15:0])};
                                4'b0001: way0_wdata <= {rpl_cacheline_buf0[127:24],  (mem_dc_data_write_i[15:0]), rpl_cacheline_buf0[7:0]};
                                4'b0010: way0_wdata <= {rpl_cacheline_buf0[127:32],  (mem_dc_data_write_i[15:0]), rpl_cacheline_buf0[15:0]};
                                4'b0011: way0_wdata <= {rpl_cacheline_buf0[127:40],  (mem_dc_data_write_i[15:0]), rpl_cacheline_buf0[23:0]};
                                4'b0100: way0_wdata <= {rpl_cacheline_buf0[127:48],  (mem_dc_data_write_i[15:0]), rpl_cacheline_buf0[31:0]};
                                4'b0101: way0_wdata <= {rpl_cacheline_buf0[127:56],  (mem_dc_data_write_i[15:0]), rpl_cacheline_buf0[39:0]};
                                4'b0110: way0_wdata <= {rpl_cacheline_buf0[127:64],  (mem_dc_data_write_i[15:0]), rpl_cacheline_buf0[47:0]};
                                4'b0111: way0_wdata <= {rpl_cacheline_buf0[127:72],  (mem_dc_data_write_i[15:0]), rpl_cacheline_buf0[55:0]};
                                4'b1000: way0_wdata <= {rpl_cacheline_buf0[127:80],  (mem_dc_data_write_i[15:0]), rpl_cacheline_buf0[63:0]};
                                4'b1001: way0_wdata <= {rpl_cacheline_buf0[127:88],  (mem_dc_data_write_i[15:0]), rpl_cacheline_buf0[71:0]};
                                4'b1010: way0_wdata <= {rpl_cacheline_buf0[127:96],  (mem_dc_data_write_i[15:0]), rpl_cacheline_buf0[79:0]};
                                4'b1011: way0_wdata <= {rpl_cacheline_buf0[127:104], (mem_dc_data_write_i[15:0]), rpl_cacheline_buf0[87:0]};
                                4'b1100: way0_wdata <= {rpl_cacheline_buf0[127:112], (mem_dc_data_write_i[15:0]), rpl_cacheline_buf0[95:0]};
                                4'b1101: way0_wdata <= {rpl_cacheline_buf0[127:120], (mem_dc_data_write_i[15:0]), rpl_cacheline_buf0[103:0]};
                                4'b1110: way0_wdata <= {(mem_dc_data_write_i[15:0]), rpl_cacheline_buf0[111:0]};
                                4'b1111: way0_wdata <= {(mem_dc_data_write_i[7:0] ), rpl_cacheline_buf0[119:0]};
                                default: ;
                            endcase
                            end
                        else if(mem_dc_wmask_i == 8'b0000_0001)begin
                            case(mem_addr_offset[D_OFFSET-1:0])
                                4'b0000: way0_wdata <= {rpl_cacheline_buf0[127:8],  (mem_dc_data_write_i[7:0])};
                                4'b0001: way0_wdata <= {rpl_cacheline_buf0[127:16],  (mem_dc_data_write_i[7:0]), rpl_cacheline_buf0[7:0]};
                                4'b0010: way0_wdata <= {rpl_cacheline_buf0[127:24],  (mem_dc_data_write_i[7:0]), rpl_cacheline_buf0[15:0]};
                                4'b0011: way0_wdata <= {rpl_cacheline_buf0[127:32],  (mem_dc_data_write_i[7:0]), rpl_cacheline_buf0[23:0]};
                                4'b0100: way0_wdata <= {rpl_cacheline_buf0[127:40],  (mem_dc_data_write_i[7:0]), rpl_cacheline_buf0[31:0]};
                                4'b0101: way0_wdata <= {rpl_cacheline_buf0[127:48],  (mem_dc_data_write_i[7:0]), rpl_cacheline_buf0[39:0]};
                                4'b0110: way0_wdata <= {rpl_cacheline_buf0[127:56],  (mem_dc_data_write_i[7:0]), rpl_cacheline_buf0[47:0]};
                                4'b0111: way0_wdata <= {rpl_cacheline_buf0[127:64],  (mem_dc_data_write_i[7:0]), rpl_cacheline_buf0[55:0]};
                                4'b1000: way0_wdata <= {rpl_cacheline_buf0[127:72],  (mem_dc_data_write_i[7:0]), rpl_cacheline_buf0[63:0]};
                                4'b1001: way0_wdata <= {rpl_cacheline_buf0[127:80],  (mem_dc_data_write_i[7:0]), rpl_cacheline_buf0[71:0]};
                                4'b1010: way0_wdata <= {rpl_cacheline_buf0[127:88],  (mem_dc_data_write_i[7:0]), rpl_cacheline_buf0[79:0]};
                                4'b1011: way0_wdata <= {rpl_cacheline_buf0[127:96],  (mem_dc_data_write_i[7:0]), rpl_cacheline_buf0[87:0]};
                                4'b1100: way0_wdata <= {rpl_cacheline_buf0[127:104], (mem_dc_data_write_i[7:0]), rpl_cacheline_buf0[95:0]};
                                4'b1101: way0_wdata <= {rpl_cacheline_buf0[127:112], (mem_dc_data_write_i[7:0]), rpl_cacheline_buf0[103:0]};
                                4'b1110: way0_wdata <= {rpl_cacheline_buf0[127:120], (mem_dc_data_write_i[7:0]), rpl_cacheline_buf0[111:0]};
                                4'b1111: way0_wdata <= {(mem_dc_data_write_i[7:0] ), rpl_cacheline_buf0[119:0]};
                                default: ;
                            endcase
                            end
                        end
//==================write way1========================
                    else if(hit_way1)begin//write way1 
                        way1_tag[mem_addr_index][D_TAG] <= 1;
                        way0_cen <= 0; way0_wen <= 1;
                        way1_cen <= 0; way1_wen <= 0;
                        if(mem_dc_wmask_i == 8'b1111_1111)begin
                            case(mem_addr_offset[D_OFFSET-1:0])
                                4'b0000: way1_wdata <= {rpl_cacheline_buf1[127:64],  (mem_dc_data_write_i[63:0])};
                                4'b0001: way1_wdata <= {rpl_cacheline_buf1[127:72],  (mem_dc_data_write_i[63:0]), rpl_cacheline_buf1[7:0]};
                                4'b0010: way1_wdata <= {rpl_cacheline_buf1[127:80],  (mem_dc_data_write_i[63:0]), rpl_cacheline_buf1[15:0]};
                                4'b0011: way1_wdata <= {rpl_cacheline_buf1[127:88],  (mem_dc_data_write_i[63:0]), rpl_cacheline_buf1[23:0]};
                                4'b0100: way1_wdata <= {rpl_cacheline_buf1[127:96],  (mem_dc_data_write_i[63:0]), rpl_cacheline_buf1[31:0]};
                                4'b0101: way1_wdata <= {rpl_cacheline_buf1[127:104], (mem_dc_data_write_i[63:0]), rpl_cacheline_buf1[39:0]};
                                4'b0110: way1_wdata <= {rpl_cacheline_buf1[127:112], (mem_dc_data_write_i[63:0]), rpl_cacheline_buf1[47:0]};
                                4'b0111: way1_wdata <= {rpl_cacheline_buf1[127:120], (mem_dc_data_write_i[63:0]), rpl_cacheline_buf1[55:0]};
                                4'b1000: way1_wdata <= {(mem_dc_data_write_i[63:0]), rpl_cacheline_buf1[63:0]};
                                4'b1001: way1_wdata <= {(mem_dc_data_write_i[55:0]), rpl_cacheline_buf1[71:0]};
                                4'b1010: way1_wdata <= {(mem_dc_data_write_i[47:0]), rpl_cacheline_buf1[79:0]};
                                4'b1011: way1_wdata <= {(mem_dc_data_write_i[39:0]), rpl_cacheline_buf1[87:0]};
                                4'b1100: way1_wdata <= {(mem_dc_data_write_i[31:0]), rpl_cacheline_buf1[95:0]};
                                4'b1101: way1_wdata <= {(mem_dc_data_write_i[23:0]), rpl_cacheline_buf1[103:0]};
                                4'b1110: way1_wdata <= {(mem_dc_data_write_i[15:0]), rpl_cacheline_buf1[111:0]};
                                4'b1111: way1_wdata <= {(mem_dc_data_write_i[7:0] ), rpl_cacheline_buf1[119:0]};
                                default: ;
                            endcase
                            end
                        else if(mem_dc_wmask_i == 8'b0000_1111)begin
                            case(mem_addr_offset[D_OFFSET-1:0])
                                4'b0000: way1_wdata <= {rpl_cacheline_buf1[127:32],  (mem_dc_data_write_i[31:0])};
                                4'b0001: way1_wdata <= {rpl_cacheline_buf1[127:40],  (mem_dc_data_write_i[31:0]), rpl_cacheline_buf1[7:0]};
                                4'b0010: way1_wdata <= {rpl_cacheline_buf1[127:48],  (mem_dc_data_write_i[31:0]), rpl_cacheline_buf1[15:0]};
                                4'b0011: way1_wdata <= {rpl_cacheline_buf1[127:56],  (mem_dc_data_write_i[31:0]), rpl_cacheline_buf1[23:0]};
                                4'b0100: way1_wdata <= {rpl_cacheline_buf1[127:64],  (mem_dc_data_write_i[31:0]), rpl_cacheline_buf1[31:0]};
                                4'b0101: way1_wdata <= {rpl_cacheline_buf1[127:72],  (mem_dc_data_write_i[31:0]), rpl_cacheline_buf1[39:0]};
                                4'b0110: way1_wdata <= {rpl_cacheline_buf1[127:80],  (mem_dc_data_write_i[31:0]), rpl_cacheline_buf1[47:0]};
                                4'b0111: way1_wdata <= {rpl_cacheline_buf1[127:88],  (mem_dc_data_write_i[31:0]), rpl_cacheline_buf1[55:0]};
                                4'b1000: way1_wdata <= {rpl_cacheline_buf1[127:96],  (mem_dc_data_write_i[31:0]), rpl_cacheline_buf1[63:0]};
                                4'b1001: way1_wdata <= {rpl_cacheline_buf1[127:104], (mem_dc_data_write_i[31:0]), rpl_cacheline_buf1[71:0]};
                                4'b1010: way1_wdata <= {rpl_cacheline_buf1[127:112], (mem_dc_data_write_i[31:0]), rpl_cacheline_buf1[79:0]};
                                4'b1011: way1_wdata <= {rpl_cacheline_buf1[127:120], (mem_dc_data_write_i[31:0]), rpl_cacheline_buf1[87:0]};
                                4'b1100: way1_wdata <= {(mem_dc_data_write_i[31:0]), rpl_cacheline_buf1[95:0]};
                                4'b1101: way1_wdata <= {(mem_dc_data_write_i[23:0]), rpl_cacheline_buf1[103:0]};
                                4'b1110: way1_wdata <= {(mem_dc_data_write_i[15:0]), rpl_cacheline_buf1[111:0]};
                                4'b1111: way1_wdata <= {(mem_dc_data_write_i[7:0] ), rpl_cacheline_buf1[119:0]};
                                default: ;
                            endcase
                            end
                        else if(mem_dc_wmask_i == 8'b0000_0011)begin
                            case(mem_addr_offset[D_OFFSET-1:0])
                                4'b0000: way1_wdata <= {rpl_cacheline_buf1[127:16],  (mem_dc_data_write_i[15:0])};
                                4'b0001: way1_wdata <= {rpl_cacheline_buf1[127:24],  (mem_dc_data_write_i[15:0]), rpl_cacheline_buf1[7:0]};
                                4'b0010: way1_wdata <= {rpl_cacheline_buf1[127:32],  (mem_dc_data_write_i[15:0]), rpl_cacheline_buf1[15:0]};
                                4'b0011: way1_wdata <= {rpl_cacheline_buf1[127:40],  (mem_dc_data_write_i[15:0]), rpl_cacheline_buf1[23:0]};
                                4'b0100: way1_wdata <= {rpl_cacheline_buf1[127:48],  (mem_dc_data_write_i[15:0]), rpl_cacheline_buf1[31:0]};
                                4'b0101: way1_wdata <= {rpl_cacheline_buf1[127:56],  (mem_dc_data_write_i[15:0]), rpl_cacheline_buf1[39:0]};
                                4'b0110: way1_wdata <= {rpl_cacheline_buf1[127:64],  (mem_dc_data_write_i[15:0]), rpl_cacheline_buf1[47:0]};
                                4'b0111: way1_wdata <= {rpl_cacheline_buf1[127:72],  (mem_dc_data_write_i[15:0]), rpl_cacheline_buf1[55:0]};
                                4'b1000: way1_wdata <= {rpl_cacheline_buf1[127:80],  (mem_dc_data_write_i[15:0]), rpl_cacheline_buf1[63:0]};
                                4'b1001: way1_wdata <= {rpl_cacheline_buf1[127:88],  (mem_dc_data_write_i[15:0]), rpl_cacheline_buf1[71:0]};
                                4'b1010: way1_wdata <= {rpl_cacheline_buf1[127:96],  (mem_dc_data_write_i[15:0]), rpl_cacheline_buf1[79:0]};
                                4'b1011: way1_wdata <= {rpl_cacheline_buf1[127:104], (mem_dc_data_write_i[15:0]), rpl_cacheline_buf1[87:0]};
                                4'b1100: way1_wdata <= {rpl_cacheline_buf1[127:112], (mem_dc_data_write_i[15:0]), rpl_cacheline_buf1[95:0]};
                                4'b1101: way1_wdata <= {rpl_cacheline_buf1[127:120], (mem_dc_data_write_i[15:0]), rpl_cacheline_buf1[103:0]};
                                4'b1110: way1_wdata <= {(mem_dc_data_write_i[15:0]), rpl_cacheline_buf1[111:0]};
                                4'b1111: way1_wdata <= {(mem_dc_data_write_i[7:0] ), rpl_cacheline_buf1[119:0]};
                                default: ;
                            endcase
                            end
                        else if(mem_dc_wmask_i == 8'b0000_0001)begin
                            case(mem_addr_offset[D_OFFSET-1:0])
                                4'b0000: way1_wdata <= {rpl_cacheline_buf1[127:8],   (mem_dc_data_write_i[7:0])};
                                4'b0001: way1_wdata <= {rpl_cacheline_buf1[127:16],  (mem_dc_data_write_i[7:0]), rpl_cacheline_buf1[7:0]};
                                4'b0010: way1_wdata <= {rpl_cacheline_buf1[127:24],  (mem_dc_data_write_i[7:0]), rpl_cacheline_buf1[15:0]};
                                4'b0011: way1_wdata <= {rpl_cacheline_buf1[127:32],  (mem_dc_data_write_i[7:0]), rpl_cacheline_buf1[23:0]};
                                4'b0100: way1_wdata <= {rpl_cacheline_buf1[127:40],  (mem_dc_data_write_i[7:0]), rpl_cacheline_buf1[31:0]};
                                4'b0101: way1_wdata <= {rpl_cacheline_buf1[127:48],  (mem_dc_data_write_i[7:0]), rpl_cacheline_buf1[39:0]};
                                4'b0110: way1_wdata <= {rpl_cacheline_buf1[127:56],  (mem_dc_data_write_i[7:0]), rpl_cacheline_buf1[47:0]};
                                4'b0111: way1_wdata <= {rpl_cacheline_buf1[127:64],  (mem_dc_data_write_i[7:0]), rpl_cacheline_buf1[55:0]};
                                4'b1000: way1_wdata <= {rpl_cacheline_buf1[127:72],  (mem_dc_data_write_i[7:0]), rpl_cacheline_buf1[63:0]};
                                4'b1001: way1_wdata <= {rpl_cacheline_buf1[127:80],  (mem_dc_data_write_i[7:0]), rpl_cacheline_buf1[71:0]};
                                4'b1010: way1_wdata <= {rpl_cacheline_buf1[127:88],  (mem_dc_data_write_i[7:0]), rpl_cacheline_buf1[79:0]};
                                4'b1011: way1_wdata <= {rpl_cacheline_buf1[127:96],  (mem_dc_data_write_i[7:0]), rpl_cacheline_buf1[87:0]};
                                4'b1100: way1_wdata <= {rpl_cacheline_buf1[127:104], (mem_dc_data_write_i[7:0]), rpl_cacheline_buf1[95:0]};
                                4'b1101: way1_wdata <= {rpl_cacheline_buf1[127:112], (mem_dc_data_write_i[7:0]), rpl_cacheline_buf1[103:0]};
                                4'b1110: way1_wdata <= {rpl_cacheline_buf1[127:120], (mem_dc_data_write_i[7:0]), rpl_cacheline_buf1[111:0]};
                                4'b1111: way1_wdata <= {(mem_dc_data_write_i[7:0] ), rpl_cacheline_buf1[119:0]};
                                default: ;
                            endcase
                            end
                        end
                    end  
//=====================finish=========================               
                READY:  begin
                        mem_dc_ready_o <= 1;
                        way0_cen <= 1; way0_wen <= 1;
                        way1_cen <= 1; way1_wen <= 1;
                end
                MISS:begin
                        arb_dc_valid_o <= 1;
                        arb_dc_rw_req_o <= 1'b0;//read
                        arb_dc_addr_o <= {mem_dc_addr_i[`AXI_ADDR_WIDTH-1:4],4'b0};//0x18 axi_rd error ! 0x10 inst need first instead of 0x18
                    if(age == 0) begin//replace way 0.
                        rpl_en <= way0_tag[mem_addr_index][D_TAG:D_TAG-1];
                        way0_cen <= 0; way0_wen <= 1; 
                        way1_cen <= 1; way1_wen <= 1;
                    end
                    else begin//replace way 1.
                        rpl_en <= way1_tag[mem_addr_index][D_TAG:D_TAG-1];
                        way0_cen <= 1; way0_wen <= 1; 
                        way1_cen <= 0; way1_wen <= 1;
                    end
                end
                REPLACE:begin //if dirty write back to dram.
                    if(rpl_en == 2'b11 && age == 0)begin//dirty,valid = 2'b11 replace way0.
                        way0_wdata_buf <= arb_dc_data_read_i;
                        arb_dc_valid_o <= 1;
                        arb_dc_data_write_o <= rpl_cacheline_buf0;
                        arb_dc_rw_req_o <= 1'b1;//write trans
                        arb_dc_addr_o <= {way0_tag[mem_addr_index][D_TAG-2 :0], mem_addr_index, 4'b0};//tag,index,offset write back addr
                        way0_tag[mem_addr_index][D_TAG:D_TAG-1] <= 2'b01;
                    end
                    else if(rpl_en == 2'b11 && age == 1)begin
                        way1_wdata_buf <= arb_dc_data_read_i;
                        arb_dc_valid_o <= 1;
                        arb_dc_data_write_o <= rpl_cacheline_buf1;
                        arb_dc_rw_req_o <= 1'b1;//write trans
                        arb_dc_addr_o <= {way1_tag[mem_addr_index][D_TAG-2 :0], mem_addr_index, 4'b0};//tag,index,offset write back addr
                        way1_tag[mem_addr_index][D_TAG:D_TAG-1] <= 2'b01;
                    end
                    else if(rpl_en[1] == 0  && age == 0)begin//if undirty.throw out.
                        way0_wdata_buf <= arb_dc_data_read_i;
                        arb_dc_valid_o <= 0;
                        way0_tag[mem_addr_index][D_TAG:D_TAG-1] <= 2'b01;
                    end
                    else if(rpl_en[1] == 0  && age == 1)begin
                        way1_wdata_buf <= arb_dc_data_read_i;
                        arb_dc_valid_o <= 0;
                        way1_tag[mem_addr_index][D_TAG:D_TAG-1] <= 2'b01;
                    end
                end
                REFILL:begin
                        arb_dc_valid_o <= 0;
                        arb_dc_rw_req_o <= 1'b0;
                    if(!age)begin//LRU refill use age.
                        way0_tag[mem_addr_index][D_TAG:0] <= {1'b0, 1'b1, mem_addr_tag};//dirty,valid,tag
                        way0_wdata <= way0_wdata_buf;
                        way0_cen <= 0; 
                        way0_wen <= 0;
                    end
                    else begin
                        way1_tag[mem_addr_index][D_TAG:0] <= {1'b0, 1'b1, mem_addr_tag};
                        way1_wdata <= way1_wdata_buf;
                        way1_cen <= 0;
                        way1_wen <= 0;
                    end              
                end
                default:begin
                        way0_cen <= 1;
                        way0_wen <= 1;
                        way1_cen <= 1;
                        way1_wen <= 1;
                    end
            endcase
        end
    end
                   
//3.1 TAG equal! hit the cache and return the inst according the OFFSET.（valid == 1）
    //AXI-->DCACHE-->MEM 
    //read data.
    always_comb begin
        if(hit_way0)
            case(mem_addr_offset[D_OFFSET-1:0])
                4'b0000: mem_dc_data_read_o = way0_rdata[63:0];
                4'b0001: mem_dc_data_read_o = way0_rdata[71:8];
                4'b0010: mem_dc_data_read_o = way0_rdata[79:16];
                4'b0011: mem_dc_data_read_o = way0_rdata[87:24];
                4'b0100: mem_dc_data_read_o = way0_rdata[95:32];
                4'b0101: mem_dc_data_read_o = way0_rdata[103:40];
                4'b0110: mem_dc_data_read_o = way0_rdata[111:48];
                4'b0111: mem_dc_data_read_o = way0_rdata[119:56];
                4'b1000: mem_dc_data_read_o = way0_rdata[127:64];
                4'b1001: mem_dc_data_read_o = {8'b0,  way0_rdata[127:72]};
                4'b1010: mem_dc_data_read_o = {16'b0, way0_rdata[127:80]};
                4'b1011: mem_dc_data_read_o = {24'b0, way0_rdata[127:88]};
                4'b1100: mem_dc_data_read_o = {32'b0, way0_rdata[127:96]};
                4'b1101: mem_dc_data_read_o = {40'b0, way0_rdata[127:104]};
                4'b1110: mem_dc_data_read_o = {48'b0, way0_rdata[127:112]};
                4'b1111: mem_dc_data_read_o = {56'b0, way0_rdata[127:120]};
                default:;
            endcase
        else if(hit_way1)
            case(mem_addr_offset[D_OFFSET-1:0])
                4'b0000: mem_dc_data_read_o = way1_rdata[63:0];
                4'b0001: mem_dc_data_read_o = way1_rdata[71:8];
                4'b0010: mem_dc_data_read_o = way1_rdata[79:16];
                4'b0011: mem_dc_data_read_o = way1_rdata[87:24];
                4'b0100: mem_dc_data_read_o = way1_rdata[95:32];
                4'b0101: mem_dc_data_read_o = way1_rdata[103:40];
                4'b0110: mem_dc_data_read_o = way1_rdata[111:48];
                4'b0111: mem_dc_data_read_o = way1_rdata[119:56];
                4'b1000: mem_dc_data_read_o = way1_rdata[127:64];
                4'b1001: mem_dc_data_read_o = {8'b0,  way1_rdata[127:72]};
                4'b1010: mem_dc_data_read_o = {16'b0, way1_rdata[127:80]};
                4'b1011: mem_dc_data_read_o = {24'b0, way1_rdata[127:88]};
                4'b1100: mem_dc_data_read_o = {32'b0, way1_rdata[127:96]};
                4'b1101: mem_dc_data_read_o = {40'b0, way1_rdata[127:104]};
                4'b1110: mem_dc_data_read_o = {48'b0, way1_rdata[127:112]};
                4'b1111: mem_dc_data_read_o = {56'b0, way1_rdata[127:120]};
                default:;
            endcase
        else
            mem_dc_data_read_o = 64'b0;
    end

    //wrdate to cache.
    /*always_comb begin
        way0_wdata = 128'b0;
        way1_wdata = 128'b0;
        if(hit_way0)
            case(mem_addr_offset[D_OFFSET-1:D_OFFSET-2])
                2'b00: way0_wdata[63: 0]  = mem_dc_data_write_i[63:0];
                2'b01: way0_wdata[95:32]  = mem_dc_data_write_i[63:0];
                2'b10: way0_wdata[127:64] = mem_dc_data_write_i[63:0];
                2'b11: way0_wdata[127:96] = mem_dc_data_write_i[31:0];
                default: ;
            endcase
        else if(hit_way1)
            case(mem_addr_offset[D_OFFSET-1:D_OFFSET-2])
                2'b00: way1_wdata[63: 0]  = mem_dc_data_write_i[63:0];
                2'b01: way1_wdata[95:32]  = mem_dc_data_write_i[63:0];
                2'b10: way1_wdata[127:64] = mem_dc_data_write_i[63:0];
                2'b11: way1_wdata[127:96] = mem_dc_data_write_i[31:0];
                default:;
            endcase
        else begin
            way0_wdata = 128'b0;
            way1_wdata = 128'b0;
        end
    end*/

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
    
//2-WAY CACHE use 128bit*64 SRAM
    logic [CACHE_LINE_WIDTH-1:0]     way0_rdata, way1_rdata;
    logic                            way0_cen,   way1_cen  ;
    logic                            way0_wen,   way1_wen  ;
    logic [CACHE_LINE_WIDTH-1:0]     way0_wdata, way1_wdata, way0_wdata_buf, way1_wdata_buf;

cache_ram u_way0(.Q( way0_rdata), .CLK (clk), .CEN (way0_cen), .WEN (way0_wen ), .A(mem_addr_index), .D(way0_wdata) );
cache_ram u_way1(.Q( way1_rdata), .CLK (clk), .CEN (way1_cen), .WEN (way1_wen ), .A(mem_addr_index), .D(way1_wdata) );

endmodule

//END