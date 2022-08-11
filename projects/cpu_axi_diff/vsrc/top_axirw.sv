//
`include "rvseed_defines.sv"
`define AXI_TOP_INTERFACE(name) io_memAXI_0_``name

module top_axirw(
    input                               clock,
    input                               rst_n,
  // aw:
  input  logic                      i_axi_aw_ready  ,         
  output logic                      o_axi_aw_valid  ,
  output logic [`DATA_WIDTH-1:0]     o_axi_aw_addr   ,
  output logic [2:0]                o_axi_aw_prot   ,
  output logic [3:0]                o_axi_aw_id     ,
  output logic                      o_axi_aw_user   ,
  output logic [7:0]                o_axi_aw_len    ,
  output logic [2:0]                o_axi_aw_size   ,
  output logic [1:0]                o_axi_aw_burst  ,
  output logic                      o_axi_aw_lock   ,
  output logic [3:0]                o_axi_aw_cache  ,
  output logic [3:0]                o_axi_aw_qos    ,
  output logic [3:0]                o_axi_aw_region ,
  // w:
  input  logic                      i_axi_w_ready   ,                
  output logic                      o_axi_w_valid   ,
  output logic [`DATA_WIDTH-1:0]     o_axi_w_data   ,
  output logic [`DATA_WIDTH/8-1:0]   o_axi_w_strb   ,
  output logic                      o_axi_w_last    ,
  output logic                      o_axi_w_user    ,
  // b:
  output logic                      o_axi_b_ready   ,                
  input  logic                      i_axi_b_valid   ,
  input  logic [1:0]                i_axi_b_resp    ,                 
  input  logic [3:0]                i_axi_b_id      ,
  input  logic                      i_axi_b_user    ,
  // ar:
  input  logic                      i_axi_ar_ready  ,                
  output logic                      o_axi_ar_valid  ,
  output logic [`DATA_WIDTH-1:0]     o_axi_ar_addr   ,
  output logic [2:0]                o_axi_ar_prot   ,
  output logic [3:0]                o_axi_ar_id     ,
  output logic                      o_axi_ar_user   ,
  output logic [7:0]                o_axi_ar_len    ,
  output logic [2:0]                o_axi_ar_size   ,
  output logic [1:0]                o_axi_ar_burst  ,
  output logic                      o_axi_ar_lock   ,
  output logic [3:0]                o_axi_ar_cache  ,
  output logic [3:0]                o_axi_ar_qos    ,
  output logic [3:0]                o_axi_ar_region ,
  // r:
  output logic                      o_axi_r_ready   ,                 
  input  logic                      i_axi_r_valid   ,                
  input  logic [1:0]                i_axi_r_resp    ,
  input  logic [`DATA_WIDTH-1:0]     i_axi_r_data    ,
  input  logic                      i_axi_r_last    ,
  input  logic [3:0]                i_axi_r_id      ,
  input  logic                      i_axi_r_user    ,
  output logic                      s_uart_out_valid,
  output logic [7:0]                s_uart_out_char
);
// 0.RESET TREE
    logic rst_n_sync;
    sync_reset_async_release u_reset_tree(
        .clock                             (clock                       ),
        .reset_n                           (rst_n                   ),

        .rst_n                             (rst_n_sync                     ) 
    );
// 1. AXI4 INTERFACE assign to SimTop
    axi4_if #(.AXI_ADDR_WIDTH(`DATA_WIDTH), .AXI_DATA_WIDTH(`DATA_WIDTH), .AXI_ID_WIDTH(4), .AXI_USER_WIDTH(1)) axi_if();
    axi_rw u_axi_rw (
        .clock                          (clock),
        .reset_n                         (rst_n_sync),

        .rw_valid_i                     (rw_valid_i),
        .rw_ready_o                     (rw_ready_o),
        .rw_req_i                       (rw_req_i),
        .data_read_o                    (data_read_o),
        .data_write_i                   (data_write_i),
        .rw_addr_i                      (rw_addr_i),
        .rw_size_i                      (rw_size_i),
        .rw_resp_o                      (rw_resp_o),
        .rw_wmask_i                     (rw_wmask),//for write' 

        //AXI4-LITE INTERFACE
        .Axi4_M                         (axi_if)
    ); 
    assign axi_if.aw_ready = i_axi_aw_ready   ;
    assign o_axi_aw_valid  = axi_if.aw_valid  ;
    assign o_axi_aw_addr   = axi_if.aw_addr   ;
    assign o_axi_aw_prot   = axi_if.aw_prot   ;
    assign o_axi_aw_id     = axi_if.aw_id     ;
    assign o_axi_aw_user   = axi_if.aw_user   ;
    assign o_axi_aw_len    = axi_if.aw_len    ;
    assign o_axi_aw_size   = axi_if.aw_size   ;
    assign o_axi_aw_burst  = axi_if.aw_burst  ;
    assign o_axi_aw_lock   = axi_if.aw_lock   ;
    assign o_axi_aw_cache  = axi_if.aw_cache  ;
    assign o_axi_aw_qos    = axi_if.aw_qos    ;
    assign o_axi_aw_region = axi_if.aw_region ;

    assign axi_if.w_ready  = i_axi_w_ready    ;
    assign o_axi_w_valid   = axi_if.w_valid   ;
    assign o_axi_w_data    = axi_if.w_data    ;
    assign o_axi_w_strb    = axi_if.w_strb    ;
    assign o_axi_w_last    = axi_if.w_last    ;
    assign o_axi_w_user    = axi_if.w_user    ;

    assign o_axi_b_ready   = axi_if.b_ready   ;
    assign axi_if.b_valid  = i_axi_b_valid    ;
    assign axi_if.b_resp   = i_axi_b_resp     ;
    assign axi_if.b_id     = i_axi_b_id       ;
    assign axi_if.b_user   = i_axi_b_user     ;

    assign axi_if.ar_ready = i_axi_ar_ready   ;
    assign o_axi_ar_valid  = axi_if.ar_valid  ;
    assign o_axi_ar_addr   = axi_if.ar_addr   ;
    assign o_axi_ar_prot   = axi_if.ar_prot   ;
    assign o_axi_ar_id     = axi_if.ar_id     ;
    assign o_axi_ar_user   = axi_if.ar_user   ;
    assign o_axi_ar_len    = axi_if.ar_len    ;
    assign o_axi_ar_size   = axi_if.ar_size   ;
    assign o_axi_ar_burst  = axi_if.ar_burst  ;
    assign o_axi_ar_lock   = axi_if.ar_lock   ;
    assign o_axi_ar_cache  = axi_if.ar_cache  ;
    assign o_axi_ar_qos    = axi_if.ar_qos    ;
    assign o_axi_ar_region = axi_if.ar_region ;

    assign o_axi_r_ready   = axi_if.r_ready   ;
    assign axi_if.r_valid  = i_axi_r_valid    ;
    assign axi_if.r_resp   = i_axi_r_resp     ;
    assign axi_if.r_data   = i_axi_r_data     ;
    assign axi_if.r_last   = i_axi_r_last     ;
    assign axi_if.r_id     = i_axi_r_id       ;
    assign axi_if.r_user   = i_axi_r_user     ;   
    //connect AXI_RW and CPU
    logic                  rw_valid_i;   
    logic              rw_ready_o  ;
    logic              rw_req_i   ;  
    logic [  63:0]         data_read_o;  
    logic [  63:0]         data_write_i; 
    logic [  63:0]         rw_addr_i;    
    logic [   1:0]         rw_size_i;    
    logic [   1:0]         rw_resp_o;    
    logic [7:0] rw_wmask;
    logic if_valid;
    logic if_ready;
    wire if_req = `REQ_READ;
    logic [63:0] if_data_read;
    logic [63:0] if_addr;
    logic [1:0] if_size;
    logic [1:0] if_resp;

    logic mem_valid;
    logic mem_ready;
    logic mem_req ;
    logic [63:0] mem_data_read;
    logic [63:0] mem_data_write;
    logic [63:0] mem_addr;
    logic [1:0] mem_size;
    logic [1:0] mem_resp;

    logic [7:0] mem_wmask;

// 2. Arbiter for IFU/MEM to axi_rw
logic grant;
if_mem_axi_rw_arbiter u_if_mem_axi_rw_arbiter(
    .clk             ( clock             ),
    .reset_n         ( rst_n_sync         ),

    .if_valid        ( if_valid        ),
    .if_ready        ( if_ready        ),
    .if_req          ( if_req          ),
    .if_data_read    ( if_data_read    ),
    .if_addr         ( if_addr         ),
    .if_size         ( if_size         ),
    .if_resp         ( if_resp         ),

    .mem_valid       ( mem_valid       ),
    .mem_ready       ( mem_ready       ),
    .mem_req         ( mem_req         ),
    .mem_data_read   ( mem_data_read   ),
    .mem_data_write  ( mem_data_write  ),
    .mem_addr        ( mem_addr        ),
    .mem_size        ( mem_size        ),
    .mem_resp        ( mem_resp        ),
    .mem_wmask       ( mem_wmask       ),

    .grant(grant),
    .rw_valid_i      ( rw_valid_i      ),
    .rw_ready_o      ( rw_ready_o      ),
    .rw_req_i        ( rw_req_i        ),
    .data_read_o     ( data_read_o     ),
    .data_write_i    ( data_write_i    ),
    .rw_addr_i       ( rw_addr_i       ),
    .rw_size_i       ( rw_size_i       ),
    .rw_resp_o       ( rw_resp_o       ),
    .rw_wmask(rw_wmask)
);

    top u_cpu(
        .clk                            (clock),
        .rst_n                          (rst_n_sync),

        .grant(grant),
//IF
        .if_valid                       (if_valid),
        .if_ready                       (if_ready),
        .if_data_read                   (if_data_read),
        .if_addr                        (if_addr),
        .if_size                        (if_size),
        .if_resp                        (if_resp),
//MEM
        .mem_valid                      (mem_valid),
        .mem_ready                      (mem_ready),
        .mem_rw_req                     (mem_req),
        .mem_data_read                  (mem_data_read),
        .mem_data_write                 (mem_data_write),
        .mem_addr                       (mem_addr),
        .mem_size                       (mem_size),
        .mem_resp                       (mem_resp),

        .mem_wmask                      (mem_wmask)
    );


endmodule