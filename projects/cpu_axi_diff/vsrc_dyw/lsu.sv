module lsu (
  input  logic                    i_clk         ,
  input  logic                    i_rst_n       ,
  input  logic                    i_flush       ,

  // 1. axi interface to get data from mem:
  uni_if.Master                   UniIf_M       ,

  // 2. signal to pipe shake hands:
  input  logic                    i_pre_valid   ,   // from pre-stage
  output logic                    o_pre_ready   ,   //  to  pre-stage
  output logic                    o_post_valid  ,   //  to  post-stage
  input  logic                    i_post_ready  ,   // from post-stage

  // 3. input comb signal from pre stage:
  input  logic  [`CPU_WIDTH-1:0]  i_exu_exres   ,
  input  logic  [`CPU_WIDTH-1:0]  i_exu_rs2     ,
  input  logic  [2:0]             i_exu_lsfunc3 ,
  input  logic                    i_exu_lden    ,
  input  logic                    i_exu_sten    ,
  input  logic  [`REG_ADDRW-1:0]  i_exu_rdid    ,
  input  logic                    i_exu_rdwen   ,
  input  logic  [`CSR_ADDRW-1:0]  i_exu_csrdid  ,
  input  logic                    i_exu_csrdwen , // csr dest write enable.
  input  logic  [`CPU_WIDTH-1:0]  i_exu_csrd    ,
  input  logic  [`CPU_WIDTH-1:0]  i_exu_pc      ,
  input  logic  [`INS_WIDTH-1:0]  i_exu_ins     ,
  input  logic                    i_exu_nop     ,

  // 4. clint signals:
  output  logic                   o_clint_ren   ,
  output  logic [`CPU_WIDTH-1:0]  o_clint_raddr ,
  input   logic [`CPU_WIDTH-1:0]  i_clint_rdata ,
  output  logic                   o_clint_wen   ,
  output  logic [`CPU_WIDTH-1:0]  o_clint_waddr ,
  output  logic [`CPU_WIDTH-1:0]  o_clint_wdata ,

  // 5. output comb signal to post stage:
  output logic  [`CPU_WIDTH-1:0]  o_lsu_lsres   ,
  output logic  [`CPU_WIDTH-1:0]  o_lsu_exres   ,
  output logic                    o_lsu_lden    ,
  output logic  [`REG_ADDRW-1:0]  o_lsu_rdid    ,
  output logic                    o_lsu_rdwen   ,
  output logic  [`CSR_ADDRW-1:0]  o_lsu_csrdid  ,
  output logic                    o_lsu_csrdwen , // csr dest write enable.
  output logic  [`CPU_WIDTH-1:0]  o_lsu_csrd    ,
  output logic  [`CPU_WIDTH-1:0]  o_lsu_pc      ,
  output logic  [`INS_WIDTH-1:0]  o_lsu_ins     ,
  output logic                    o_lsu_nop     ,
  
  // 6. for sim:
  output logic                    s_lsu_lsclint
);

  // 1. shake hands to reg pre stage signals:////////////////////////////////s/////////////////////////////////

  // i_pre_valid --> ⌈‾‾‾‾⌉ --> o_post_valid
  //                 |REG|
  // o_pre_ready <-- ⌊____⌋ <-- i_post_ready

  assign o_pre_ready =  (ldst_en & addr_axi) ? (o_post_valid & i_post_ready) : (o_post_valid & i_post_ready | !o_post_valid) ;

  wire pre_sh = i_pre_valid & o_pre_ready;
  wire pre_valid_r;

  stl_reg #(
    .WIDTH      (1           ), 
    .RESET_VAL  (0           )
  ) postvalid (
  	.i_clk      (i_clk       ), 
    .i_rst_n    (i_rst_n     ), 
    .i_wen      (i_flush | o_pre_ready ), 
    .i_din      (i_flush ? 0: i_pre_valid ), 
    .o_dout     (pre_valid_r )
  );

  assign o_post_valid   = (ldst_en & addr_axi) ? UniIf_M.ready : pre_valid_r;

  logic  [`CPU_WIDTH-1:0]  exu_exres_r    ;
  logic  [`CPU_WIDTH-1:0]  exu_rs2_r      ;
  logic  [2:0]             exu_lsfunc3_r  ;
  logic                    exu_lden_r     ;
  logic                    exu_sten_r     ;
  logic  [`REG_ADDRW-1:0]  exu_rdid_r     ;
  logic                    exu_rdwen_r    ;
  logic  [`CSR_ADDRW-1:0]  exu_csrdid_r   ;
  logic                    exu_csrdwen_r  ;
  logic  [`CPU_WIDTH-1:0]  exu_csrd_r     ;
  logic  [`CPU_WIDTH-1:0]  exu_pc_r       ;
  logic  [`INS_WIDTH-1:0]  exu_ins_r      ;
  logic                    exu_nop_r      ;
  
  stl_reg #(
    .WIDTH      (4*`CPU_WIDTH+`REG_ADDRW+`CSR_ADDRW+7+`INS_WIDTH+1),
    .RESET_VAL  (0       )
  ) prereg (
  	.i_clk      (i_clk   ),
    .i_rst_n    (i_rst_n ),
    .i_wen      (i_flush | pre_sh ),
    .i_din      (i_flush ? 0: {i_exu_exres, i_exu_rs2, i_exu_lsfunc3, i_exu_lden, i_exu_sten, i_exu_rdid, i_exu_rdwen, i_exu_csrdid, i_exu_csrdwen, i_exu_csrd, i_exu_pc, i_exu_ins, i_exu_nop} ),
    .o_dout     (             {exu_exres_r, exu_rs2_r, exu_lsfunc3_r, exu_lden_r, exu_sten_r, exu_rdid_r, exu_rdwen_r, exu_csrdid_r, exu_csrdwen_r, exu_csrd_r, exu_pc_r, exu_ins_r, exu_nop_r} )
  );

  // 2. deal with device :///////////////////////////////////////////////////////////////////////////////////////
  wire load_en = pre_valid_r & exu_lden_r;
  wire stor_en = pre_valid_r & exu_sten_r;
  wire ldst_en = load_en | stor_en ;

  wire addr_clint = (exu_exres_r >= `CLINT_BASE_ADDR) & (exu_exres_r < `CLINT_END_ADDR);
  wire addr_axi   = !addr_clint;

  // 3. deal with clint :///////////////////////////////////////////////////////////////////////////////////////

  assign o_clint_ren    = addr_clint & load_en;
  assign o_clint_raddr  = exu_exres_r;

  assign o_clint_wen    = addr_clint & stor_en;
  assign o_clint_waddr  = exu_exres_r;
  assign o_clint_wdata  = exu_rs2_r  ;

  // 4. use interface to read/write, generate valid signals for post stage:////////////////////////////////////

  assign UniIf_M.valid  = addr_axi & ldst_en;
  assign UniIf_M.reqtyp = stor_en    ; 
  assign UniIf_M.addr   = exu_exres_r;
  assign UniIf_M.wdata  = exu_rs2_r  ;

  stl_mux_default #(7, 3, 2) mux_size (UniIf_M.size, exu_lsfunc3_r, 2'b00, {
    `FUNC3_LB_SB, ldst_en ? 2'b00 : 2'b00, // load + store.
    `FUNC3_LH_SH, ldst_en ? 2'b01 : 2'b00, // load + store.
    `FUNC3_LW_SW, ldst_en ? 2'b10 : 2'b00, // load + store.
    `FUNC3_LD_SD, ldst_en ? 2'b11 : 2'b00, // load + store.
    `FUNC3_LBU  , load_en ? 2'b00 : 2'b00, // only load.
    `FUNC3_LHU  , load_en ? 2'b01 : 2'b00, // only load.
    `FUNC3_LWU  , load_en ? 2'b10 : 2'b00  // only load.
  });

  // 3. use one register to save data, which is must keep for bypass ://///////////////////////////////////////
  // think about this situation: 
  // ins1 in lsu is loading data,
  // ins2 in exu is calculate division.
  // ins3 in idu, and the rs1id or rs2id == rdid(ins1).
  // so the ins1 load data in lsu must be kept, until pre stage is fire (div is done).  

  logic [`CPU_WIDTH-1:0] unif_rdata,unif_rdata_r;
  stl_mux_default #(7, 3, `CPU_WIDTH) mux_rdata (unif_rdata, exu_lsfunc3_r, `CPU_WIDTH'b0, {
    `FUNC3_LB_SB, load_en ? {{56{UniIf_M.rdata[ 7]}}, UniIf_M.rdata[ 7:0]} : `CPU_WIDTH'b0 ,
    `FUNC3_LH_SH, load_en ? {{48{UniIf_M.rdata[15]}}, UniIf_M.rdata[15:0]} : `CPU_WIDTH'b0 ,
    `FUNC3_LW_SW, load_en ? {{32{UniIf_M.rdata[31]}}, UniIf_M.rdata[31:0]} : `CPU_WIDTH'b0 ,
    `FUNC3_LD_SD, load_en ? UniIf_M.rdata                                  : `CPU_WIDTH'b0 ,
    `FUNC3_LBU  , load_en ? {56'b0, UniIf_M.rdata[ 7:0]}                   : `CPU_WIDTH'b0 ,
    `FUNC3_LHU  , load_en ? {48'b0, UniIf_M.rdata[15:0]}                   : `CPU_WIDTH'b0 ,
    `FUNC3_LWU  , load_en ? {32'b0, UniIf_M.rdata[31:0]}                   : `CPU_WIDTH'b0 
  });

  wire UniIf_Sh = UniIf_M.valid & UniIf_M.ready;

  stl_reg #(
    .WIDTH      (`CPU_WIDTH   ),
    .RESET_VAL  (`CPU_WIDTH'b0)
  ) rdatareg (
  	.i_clk      (i_clk        ),
    .i_rst_n    (i_rst_n      ),
    .i_wen      (UniIf_Sh     ),
    .i_din      (unif_rdata   ),
    .o_dout     (unif_rdata_r )
  );

  wire [`CPU_WIDTH-1:0] bus_rdata = UniIf_Sh ? unif_rdata : unif_rdata_r;

  // remind: due to the ready signal of post stage never be 0, so it is not necessary to keep the handshake of UniIf_M.

  // 4. use pre stage signals to generate comb logic for post stage://////////////////////////////////////////

  assign o_lsu_lsres   = addr_clint ? i_clint_rdata : bus_rdata;
  assign o_lsu_exres   = exu_exres_r  ;
  assign o_lsu_lden    = exu_lden_r   ;
  assign o_lsu_rdid    = exu_rdid_r   ;
  assign o_lsu_rdwen   = exu_rdwen_r  ;
  assign o_lsu_csrdid  = exu_csrdid_r ;
  assign o_lsu_csrdwen = exu_csrdwen_r;
  assign o_lsu_csrd    = exu_csrd_r   ;
  assign o_lsu_pc      = exu_pc_r     ;
  assign o_lsu_ins     = exu_ins_r    ;
  assign o_lsu_nop     = exu_nop_r    ;
  assign s_lsu_lsclint = ldst_en & addr_clint;

endmodule
