`include "rvseed_defines.sv"
//`include "vsrc/utils/syncex_pc_reset_async_release.sv"
//handshake top

module top (
    input                               clk                        ,
    input                               rst_n                      ,
    input                               grant                      ,

    //CACHE INTERFACE
    input  logic                        icache_hit,
    input  logic                        hit,
    input  logic                        hit_r,
    output logic  [`PC_WIDTH-1:0]       if_pc                      ,
    //IF INTTERFACE
    output                              if_valid                   ,
    input                               if_ready                   ,
    input              [  63:0]         if_data_read               ,
    output             [  63:0]         if_addr                    ,
    output             [   1:0]         if_size                    ,
    input              [   1:0]         if_resp                    ,
    //MEM INTTERFACE
    output                              mem_valid                  ,
    input                               mem_ready                  ,
    output                              mem_rw_req                 ,
    input              [  63:0]         mem_data_read              ,
    output             [  63:0]         mem_data_write             ,
    output             [  63:0]         mem_addr                   ,
    output             [   1:0]         mem_size                   ,
    input              [   1:0]         mem_resp                   ,
    output             [   7:0]         mem_wmask                  ,
    //top
    output                              s_uart_out_valid           ,
    output             [   7:0]         s_uart_out_char             
);
    logic    [`PC_WIDTH-1 : 0]         next_pc;
    logic    [`DATA_WIDTH-1:0]         reg10_a0;

    //for align pc with reg wr, and generate special pc means data/jump adventure.
    logic   [`PC_WIDTH-1:0]     id_diff_pc  ,
                                ex_diff_pc  ,
                                mem_diff_pc ,
                                wb_diff_pc  ;
    //for  inst
    logic   [`INST_WIDTH-1:0]   if_inst     ,
                                id_inst     ,
                                ex_inst     ,
                                mem_inst    ,
                                wb_inst     ;
    //for csr
    logic      [`CSR_ADDR_WIDTH-1 : 0]      id_csr_raddr, ex_csr_raddr, mem_csr_raddr, wb_csr_raddr;//读CSR寄存器地址
    logic                                   id_csr_ren,id_csr_wen,ex_csr_wen, mem_csr_wen, wb_csr_wen;// 写CSR寄存器标志
    logic      [`DATA_WIDTH - 1 : 0]        id_csr_rdata, ex_csr_rdata, mem_csr_rdata, wb_csr_rdata;// CSR寄存器数据
    logic      [`DATA_WIDTH - 1 : 0]        ex_csr_wdata, mem_csr_wdata, wb_csr_wdata;// 读CSR寄存器数据
    logic      [`CSR_ADDR_WIDTH-1 : 0]      id_csr_waddr, ex_csr_waddr, mem_csr_waddr, wb_csr_waddr;// 写CSR寄存器地址
    //for clint
    logic                         clint_ren   , clint_wen  , clint_mtip ;
    logic      [`DATA_WIDTH-1:0]  clint_raddr , clint_waddr, clint_rdata, clint_wdata;

    logic axi_trans_done,flush;
    assign axi_trans_done = ( mem_ready | !mem_valid) & (if_ready | !if_valid) ;
    assign flush     = (iru_excp | iru_intr) & (wbu_valid_o_next & wbu_ready);       // iru_intr not commit.
//------------------------------------------------------------------------------
//  1.IF STAGE
//------------------------------------------------------------------------------
    logic                       bubble_id_ex;
//handshake 
    logic                       ready_id2if;
    logic                       valid_if2id;
    logic                       fetched;
    
    //logic pc_add_imm_flag;
if_stage u_if_stage(
    .clk                               (clk                       ),
    .rst_n                             (rst_n                     ),
    .icache_hit(icache_hit),
    .hit(hit),
    .hit_r(hit_r),
    .flush                             (flush                     ), 

    .if_valid                          (if_valid                  ),
    .if_ready                          (if_ready                  ),
    .if_data_read                      (if_data_read              ),
    .if_addr                           (if_addr                   ),
    .if_size                           (if_size                   ),
    .if_resp                           (if_resp                   ),
    .fetched                           (fetched                   ),
    
    .iru_excp                          (iru_excp                  ),
    .iru_intr                          (iru_intr                    ),
    .iru_pc                            (iru_pc                    ),

    .mret                              (mret                      ),
    //.curr_pc                           (curr_pc                   ),
    .ex_pc                             (ex_pc                     ),
    .ex_branch                         (ex_branch                 ),
    .ex_zero                           (ex_zero                   ),
    .ex_jump                           (ex_jump                   ),
    .ex_imm                            (ex_imm                    ),
    .ex_reg1_rdata                     (ex_reg1_rdata             ),
    .ex_jalr                           (ex_jalr                   ),
    .bubble_id_ex                      (bubble_id_ex              ),

    .if_inst                           (if_inst                   ),
    .if_pc                             (if_pc                     ),
    .next_pc                           (next_pc                   ),
    .bpu_bubble                        (bpu_bubble                ),

    .ready_id2if                       (ready_id2if               ),
    .valid_if2id                       (valid_if2id               ) 
);
//------------------------------------------------------------------------------
//  2.ID STAGE
//------------------------------------------------------------------------------
    //logic pipe_wen_id;
    logic                               bpu_bubble;
    //from wbu
    logic                              wb_reg_wen;                  //from mem_wb
    logic  [`REG_ADDR_WIDTH-1 : 0]     wb_reg_waddr;
    logic   [`DATA_WIDTH-1:0]          wb_reg_wdata;

    logic                              wb_csr_reg_wen;
    logic   [`CSR_ADDR_WIDTH-1 : 0]    wb_csr_reg_waddr;
    logic   [`DATA_WIDTH-1:0]          wb_csr_reg_wdata;

    logic   [`REG_ADDR_WIDTH-1 : 0]    ex_reg1_raddr;
    logic   [`REG_ADDR_WIDTH-1 : 0]    ex_reg2_raddr;
    logic   [`REG_ADDR_WIDTH-1 : 0]    ex_reg_waddr;                // register write address
    logic                              ex_reg_wen;
    logic   [`LSU_OPT_WIDTH-1 : 0]     ex_lsu_opt;
      
    logic    [`REG_ADDR_WIDTH-1 : 0]     mem_reg_waddr;             // register write address   
    logic                                mem_reg_wen;
    logic    [`LSU_OPT_WIDTH-1 : 0]      mem_lsu_opt;
    logic    [`DATA_WIDTH-1:0]           mem_alu_res;

    logic    [`DATA_WIDTH-1:0]           ex_alu_res;

    logic    [`DATA_WIDTH-1:0]           mem_regld   ;

    logic            [`PC_WIDTH-1:0]            id_pc   ;
    logic                                       id_branch;
    logic                                       id_jump;
    logic                                       id_jalr;
    logic                                       id_reg_wen;
    logic            [`REG_ADDR_WIDTH-1 : 0]    id_reg_waddr;       // register write address
    logic            [`REG_ADDR_WIDTH-1 : 0]    id_reg1_raddr;      // register1 rd address
    logic            [`REG_ADDR_WIDTH-1 : 0]    id_reg2_raddr;      // register2 rd address
    logic            [`DATA_WIDTH-1:0]          id_arb_rdata1;
    logic            [`DATA_WIDTH-1:0]          id_arb_rdata2;
    logic            [`DATA_WIDTH-1:0]          id_imm;             // immediate
    logic            [`ALU_OP_WIDTH-1 : 0]      id_alu_op;
    logic            [`ALU_SRC_WIDTH-1 : 0]     id_alu_src_sel;
    logic            [`LSU_OPT_WIDTH-1 : 0]     id_lsu_opt;
    logic                                       id_lsu_lden;
    logic                                       id_lsu_sten;

    logic            [`CSR_IMM_WIDTH-1:0]      id_csr_zimm;


//to ex mux_ldst_bp
     logic                              bp_ld_st_ctrl;

//handshake
logic ready_ex2id ,valid_id2ex;

logic pipe_ifid_wen;
logic pipe_idex_wen;
wire                   [`REG_BUS] regs[0 : 31]                           ;//for difftest
id_stage u_id_stage(
    .clk                               (clk                       ),
    .rst_n                             (rst_n                     ),
    .flush                             (flush                     ),

    //.pipe_wen                          (pipe_wen_id                  ),
    //.bubble                            (bubble                    ),
    .bpu_bubble                        (bpu_bubble                ),
    .wb_reg_wen                        (wb_reg_wen                ),
    .real_cmt(real_cmt),
    .wb_reg_waddr                      (wb_reg_waddr              ),
    .wb_reg_wdata                      (wb_reg_wdata              ),

//CSR
    .wb_csr_reg_wen                    (wb_csr_reg_wen            ),
    .wb_csr_reg_waddr                  (wb_csr_reg_waddr          ),
    .wb_csr_reg_wdata                  (wb_csr_reg_wdata          ),

    .ex_reg1_raddr                     (ex_reg1_raddr             ),
    .ex_reg2_raddr                     (ex_reg2_raddr             ),
    .ex_reg_waddr                      (ex_reg_waddr              ),
    .ex_reg_wen                        (ex_reg_wen                ),
    .ex_diff_pc                        (ex_diff_pc                ),
    .ex_lsu_opt                        (ex_lsu_opt                ),
    .ex_lsu_sten(ex_lsu_sten),
    .ex_lsu_lden(ex_lsu_lden),
    .ex_inst(ex_inst),
    .pipe_idex_wen                     (pipe_idex_wen             ),

    .mem_reg_waddr                     (mem_reg_waddr             ),
    .mem_reg_wen                       (mem_reg_wen               ),
    .mem_lsu_opt                       (mem_lsu_opt               ),
    .mem_alu_res                       (mem_alu_res               ),
    .mem_valid                         (mem_valid                 ),
    .mem_ready                         (mem_ready                 ),
    .mem_req                           (mem_rw_req                ),
    .mem_grant                         (grant                     ),
    .ex_alu_res                        (ex_alu_res                ),
    .mem_regld                         (mem_regld                 ),
    .mem_lsu_lden(mem_lsu_lden),
    .mem_lsu_sten(mem_lsu_sten),

    .if_inst                           (if_inst                   ),
    .if_pc                             (if_pc                     ),
    .if_ready                          (if_ready),
    .pipe_ifid_wen(pipe_ifid_wen),
    .id_inst                           (id_inst                   ),
    .id_pc                             (id_pc                     ),
    .id_branch                         (id_branch                 ),
    .id_jump                           (id_jump                   ),
    .id_jalr                           (id_jalr                   ),
    .id_reg_wen                        (id_reg_wen                ),
    .id_reg_waddr                      (id_reg_waddr              ),
    .id_reg1_raddr                     (id_reg1_raddr             ),
    .id_reg2_raddr                     (id_reg2_raddr             ),
    .id_arb_rdata1                     (id_arb_rdata1             ),
    .id_arb_rdata2                     (id_arb_rdata2             ),
    .id_imm                            (id_imm                    ),
    .id_alu_op                         (id_alu_op                 ),
    .id_alu_src_sel                    (id_alu_src_sel            ),
    .id_lsu_opt                        (id_lsu_opt                ),
    .id_lsu_lden                       (id_lsu_lden               ),
    .id_lsu_sten                       (id_lsu_sten               ),
    .id_diff_pc                        (id_diff_pc                ),
//CSR
    .id_csr_raddr                      (id_csr_raddr              ),
    .id_csr_rdata                      (id_csr_rdata              ),
    .id_csr_ren                        (id_csr_ren                ),

    .id_csr_waddr                      (id_csr_waddr              ),
    .id_csr_zimm                       (id_csr_zimm               ),
    .id_csr_wen                        (id_csr_wen                ),

    .reg10_a0                          (reg10_a0                  ),
    .bubble_id_ex                      (bubble_id_ex              ),
    .bp_ld_st_ctrl                     (bp_ld_st_ctrl             ),

    .regs                              (regs                      ),//for difftest
    .valid_if2id                       (valid_if2id               ),
    .ready_ex2id                       (ready_ex2id               ),
    .valid_id2ex                       (valid_id2ex               ),
    .ready_id2if                       (ready_id2if               ) 
);
//------------------------------------------------------------------------------
//  3.EX STAGE
//------------------------------------------------------------------------------
    logic   [`PC_WIDTH-1:0]     ex_pc;
    logic                       ex_branch;                          // ex_branch type 
    logic                       ex_zero;                            // alu result is ex_zero
    logic                       ex_jump;                            // ex_jump type 
    logic   [`DATA_WIDTH-1:0]   ex_imm;                             // immediate  
    logic   [`DATA_WIDTH-1:0]   ex_reg1_rdata;                      // rs1    ex_jalr:rs1+ex_imm
    logic                       ex_jalr;
    logic             [`DATA_WIDTH-1:0]          ex_regst     ;     //ex_reg2_rdata
    logic                       ex_alu_res_valid;
    
    logic ex_lsu_lden,ex_lsu_sten;
//handshake
    logic ready_mem2ex, valid_ex2mem;
ex_stage u_ex_stage(
    .clk                               (clk                       ),
    .rst_n                             (rst_n                     ),
    .flush                             (flush                     ),
    .cmt_wb_diff_pc(cmt_wb_diff_pc),

    .bpu_bubble                        (bpu_bubble                ),
    .bubble_id_ex                      (bubble_id_ex              ),
    .bp_ld_st_ctrl                     (bp_ld_st_ctrl             ),
    .mem_regld                         (mem_regld                 ),

    .pipe_ifid_wen(pipe_ifid_wen),
    .id_inst                           (id_inst                   ),
    .id_pc                             (id_pc                     ),
    .id_branch                         (id_branch                 ),
    .id_jump                           (id_jump                   ),
    .id_jalr                           (id_jalr                   ),
    .id_reg_wen                        (id_reg_wen                ),
    .id_reg_waddr                      (id_reg_waddr              ),
    .id_reg1_raddr                     (id_reg1_raddr             ),
    .id_reg2_raddr                     (id_reg2_raddr             ),
    .id_arb_rdata1                     (id_arb_rdata1             ),
    .id_arb_rdata2                     (id_arb_rdata2             ),
    .id_imm                            (id_imm                    ),
    .id_alu_op                         (id_alu_op                 ),
    .id_alu_src_sel                    (id_alu_src_sel            ),
    .id_lsu_opt                        (id_lsu_opt                ),
    .id_lsu_lden                       (id_lsu_lden               ),
    .id_lsu_sten                       (id_lsu_sten               ),
    .id_diff_pc                        (id_diff_pc                ),

    .id_csr_rdata                      (id_csr_rdata              ),
    .id_csr_waddr                      (id_csr_waddr              ),
    .id_csr_zimm                       (id_csr_zimm               ),
    .id_csr_wen                        (id_csr_wen                ),

    .pipe_idex_wen                     (pipe_idex_wen             ),
    .ex_pc                             (ex_pc                     ),
    .ex_branch                         (ex_branch                 ),
    .ex_zero                           (ex_zero                   ),
    .ex_jalr                           (ex_jalr                   ),
    .ex_jump                           (ex_jump                   ),
    .ex_imm                            (ex_imm                    ),
    .ex_reg1_rdata                     (ex_reg1_rdata             ),
    .ex_inst                           (ex_inst                   ),
    .ex_reg_wen                        (ex_reg_wen                ),
    .ex_reg_waddr                      (ex_reg_waddr              ),
    .ex_reg1_raddr                     (ex_reg1_raddr),
    .ex_reg2_raddr                     (ex_reg2_raddr),
    .ex_alu_res                        (ex_alu_res                ),
    .ex_regst                          (ex_regst                  ),
    .ex_lsu_opt                        (ex_lsu_opt                ),
    .ex_lsu_lden                       (ex_lsu_lden               ),
    .ex_lsu_sten                       (ex_lsu_sten               ),
    .ex_diff_pc                        (ex_diff_pc                ),
    .ex_alu_res_valid                  (ex_alu_res_valid          ),//div res valid signal.


    .ex_csr_wdata                      (ex_csr_wdata              ),
    .ex_csr_waddr                      (ex_csr_waddr              ),
    .ex_csr_wen                        (ex_csr_wen                ),

    .valid_id2ex                       (valid_id2ex               ),
    .ready_mem2ex                      (ready_mem2ex              ),
    .valid_ex2mem                      (valid_ex2mem              ),
    .ready_ex2id                       (ready_ex2id               ) 
);

//------------------------------------------------------------------------------
//  4.MEM STAGE
//------------------------------------------------------------------------------
//handshake
    logic                                   ready_wb2mem = 1, valid_mem2wb;
    logic mem_lsu_valid;
    logic mem_lsu_lden,mem_lsu_sten;
    logic mem_clint_ldst;
    logic pipe_exmem_wen;
//CSR
mem_stage u_mem_stage(
    .clk                               (clk                       ),
    .rst_n                             (rst_n                     ),
    .flush                             (flush                     ),
    .cmt_wb_diff_pc(cmt_wb_diff_pc),

    .pipe_idex_wen(pipe_idex_wen),
    .ex_inst                           (ex_inst                   ),
    .ex_reg_wen                        (ex_reg_wen                ),
    .ex_reg_waddr                      (ex_reg_waddr              ),
    .ex_alu_res                        (ex_alu_res                ),
    .ex_regst                          (ex_regst                  ),
    .ex_lsu_opt                        (ex_lsu_opt                ),
    .ex_lsu_lden                       (ex_lsu_lden               ),
    .ex_lsu_sten                       (ex_lsu_sten               ),
    .ex_diff_pc                        (ex_diff_pc                ),
//CSR
    .ex_csr_wdata                      (ex_csr_wdata              ),
    .ex_csr_waddr                      (ex_csr_waddr              ),
    .ex_csr_wen                        (ex_csr_wen                ),
 
//r/w data memory from/to axi_rw
    .mem_valid_o                       (mem_valid                 ),
    .mem_ready_i                       (mem_ready                 ),
    .mem_rw_req_o                      (mem_rw_req                ),//1
    .mem_data_read_i                   (mem_data_read             ),
    .mem_data_write_o                  (mem_data_write            ),
    .mem_rw_addr_i                     (mem_addr                  ),
    .mem_rw_size_o                     (mem_size                  ),
    .mem_rw_resp_i                     (mem_resp                  ),
    .mem_write_mask_o                  (mem_wmask                 ),

    .pipe_exmem_wen(pipe_exmem_wen),
    .mem_inst                          (mem_inst                  ),
    .mem_reg_wen                       (mem_reg_wen               ),
    .mem_reg_waddr                     (mem_reg_waddr             ),
    .mem_alu_res                       (mem_alu_res               ),
    .mem_lsu_opt                       (mem_lsu_opt               ),
    .mem_lsu_lden                      (mem_lsu_lden              ),
    .mem_lsu_sten                      (mem_lsu_sten              ),
    .mem_diff_pc                       (mem_diff_pc               ),
    .mem_regld                         (mem_regld                 ),

    .lsu_valid                         (mem_lsu_valid             ),
//CSR
    .mem_csr_wdata                     (mem_csr_wdata             ),
    .mem_csr_waddr                     (mem_csr_waddr             ),
    .mem_csr_wen                       (mem_csr_wen               ),
//clint
    .clint_ren                         (clint_ren                 ),
    .clint_raddr                       (clint_raddr               ),
    .clint_rdata                       (clint_rdata               ),
    .clint_wen                         (clint_wen                 ),
    .clint_waddr                       (clint_waddr               ),
    .clint_wdata                       (clint_wdata               ),

    .valid_ex2mem                      (valid_ex2mem              ),
    .ready_wb2mem                      (ready_wb2mem              ),
    .valid_mem2wb                      (valid_mem2wb              ),
    .ready_mem2ex                      (ready_mem2ex              ),
    
    .mem_clint_ldst                    (mem_clint_ldst            ) 
);
//------------------------------------------------------------------------------
//  5.WB STAGE
//------------------------------------------------------------------------------
    logic wbu_valid_o_next;
    logic wbu_ready;
    logic wb_clint_ldst;
    assign wbu_ready = (iru_excp | iru_intr) ? (mem_lsu_lden | mem_lsu_sten) ? ( mem_ready | !mem_valid): axi_trans_done : 1;

wb_stage u_wb_stage(
    .clk                               (clk                       ),
    .rst_n                             (rst_n                     ),
    .flush                             (flush                     ),
    .cmt_wb_diff_pc                    (cmt_wb_diff_pc),
    
    .pipe_exmem_wen(pipe_exmem_wen),
    .mem_inst                          (mem_inst                  ),
    .mem_reg_wen                       (mem_reg_wen               ),
    .mem_reg_waddr                     (mem_reg_waddr             ),
    .mem_regld                         (mem_regld                 ),
    .mem_alu_res                       (mem_alu_res               ),
    .mem_lsu_opt                       (mem_lsu_opt               ),
    .mem_diff_pc                       (mem_diff_pc               ),
    .mem_clint_ldst                    (mem_clint_ldst            ),
//CSR
    .mem_csr_wdata                     (mem_csr_wdata             ),
    .mem_csr_waddr                     (mem_csr_waddr             ),
    .mem_csr_wen                       (mem_csr_wen               ),

    .wb_reg_wdata                      (wb_reg_wdata              ),
    .wb_diff_pc                        (wb_diff_pc                ),
    .wb_inst                           (wb_inst                   ),
    .wb_reg_waddr                      (wb_reg_waddr              ),
    .wb_reg_wen                        (wb_reg_wen                ),

    .wb_clint_ldst                     (wb_clint_ldst             ),
    
    .wb_csr_wdata                      (wb_csr_wdata              ),
    .wb_csr_waddr                      (wb_csr_waddr              ),
    .wb_csr_wen                        (wb_csr_wen                ),

    .valid_mem2wb                      (valid_mem2wb              ),
    .ready_next_i                      (wbu_ready                 ),
    .valid_o_next                      (wbu_valid_o_next          ),
    .ready_wb2mem                      (ready_wb2mem              ) 
);

//------------------------------------------------------------------------------
//  Clint+Iru
//------------------------------------------------------------------------------

  logic [`DATA_WIDTH-1:0]  mie           ;
  logic [`DATA_WIDTH-1:0]  mip           ;
  logic [`DATA_WIDTH-1:0]  mtvec         ;
  logic [`DATA_WIDTH-1:0]  mepc          ;
  logic [`DATA_WIDTH-1:0]  mstatus       ;
  logic [`DATA_WIDTH-1:0]  mscratch      ;
  logic                    mepc_wen      ;
  logic [`DATA_WIDTH-1:0]  mepc_wdata    ;
  logic                    mcause_wen    ;
  logic [`DATA_WIDTH-1:0]  mcause_wdata  ;
  logic                    mstatus_wen   ;
  logic [`DATA_WIDTH-1:0]  mstatus_wdata ;
  
  logic                                  iru_excp;
  logic                                  iru_intr;
  logic [`DATA_WIDTH-1:0]                iru_pc     ;
  logic                     mret;
iru u_iru(
    .wb_valid                          (wbu_valid_o_next          ),
    .wb_ready                          (wbu_ready                 ),
    //.wbu_nop          ( wbu_nop          ),
    .wb_inst                           (wb_inst                   ),
    .wb_pc                             (wb_diff_pc                ),
    .i_clint_mtip                      (clint_mtip                ),

    .o_iru_excp                        (iru_excp                  ),
    .o_iru_intr                        (iru_intr                  ),
    .o_iru_pc                          (iru_pc                    ),///
    .mret                              (mret                      ),

    .mie                               (mie                       ),
    .mip                               (mip                       ),
    .mtvec                             (mtvec                     ),
    .mepc                              (mepc                      ),
    .mstatus                           (mstatus                   ),

    .o_mepc_wen                        (mepc_wen                  ),
    .o_mepc_wdata                      (mepc_wdata                ),
    .o_mcause_wen                      (mcause_wen                ),
    .o_mcause_wdata                    (mcause_wdata              ),
    .o_mstatus_wen                     (mstatus_wen               ),
    .o_mstatus_wdata                   (mstatus_wdata             ) 
);


clint u_clint(
    .clk                               (clk                       ),
    .rst_n                             (rst_n                     ),
    .clint_ren                         (clint_ren                 ),
    .clint_raddr                       (clint_raddr               ),
    .clint_rdata                       (clint_rdata               ),
    .clint_wen                         (clint_wen                 ),
    .clint_waddr                       (clint_waddr               ),
    .clint_wdata                       (clint_wdata               ),
    .o_clint_mtip                      (clint_mtip                ) 
);

//------------------------------------------------------------------------------
//  CSR REGFILES
//------------------------------------------------------------------------------

    logic     [`DATA_WIDTH-1:0]          s_mtvec         ;
    logic     [`DATA_WIDTH-1:0]          s_mstatus       ;
    logic     [`DATA_WIDTH-1:0]          s_sstatus       ;
    logic     [`DATA_WIDTH-1:0]          s_mepc          ;
    logic     [`DATA_WIDTH-1:0]          s_mcause        ;
    logic     [`DATA_WIDTH-1:0]          s_mcycle        ;
    logic     [`DATA_WIDTH-1:0]          s_mip           ;
    logic     [`DATA_WIDTH-1:0]          s_mie           ;
    logic     [`DATA_WIDTH-1:0]          s_mscratch           ;
csr_regs u_csr_regs(
    .clk                               (clk                       ),
    .rst_n                             (rst_n                     ),
    
    .mret(mret),
    .id_csr_rdata                      (id_csr_rdata              ),
    .id_csr_raddr                      (id_csr_raddr              ),
    .id_csr_ren                        (id_csr_ren                ),

    .wb_csr_wdata                      (wb_csr_wdata              ),
    .wb_csr_waddr                      (wb_csr_waddr              ),
    .wb_csr_wen                        (wb_csr_wen    ),

    .mepc_wen                          (mepc_wen                  ),
    .mepc_wdata                        (mepc_wdata                ),
    .mcause_wen                        (mcause_wen                ),
    .mcause_wdata                      (mcause_wdata              ),
    .mstatus_wen                       (mstatus_wen               ),
    .mstatus_wdata                     (mstatus_wdata             ),

    .csr_mtvec                         (mtvec                     ),
    .csr_mstatus                       (mstatus                   ),
    .csr_mepc                          (mepc                      ),
    .csr_mip                           (mip                       ),
    .csr_mie                           (mie                       ),
    .csr_mscratch                      (mscratch                  ),

    .i_clint_mtip                      (clint_mtip                ),

    .s_mtvec                           (s_mtvec                   ),
    .s_mepc                            (s_mepc                    ),
    .s_mstatus                         (s_mstatus                 ),
    .s_sstatus                         (s_sstatus                 ),
    .s_mcause                          (s_mcause                  ),
    .s_mcycle                          (s_mcycle                  ),
    .s_mie                             (s_mie                     ),
    .s_mip                             (s_mip                     ),
    .s_mscratch                        (s_mscratch                     ),
    .global_int_en                     (                          ) 
);

//------------------------------------------------------------------------------
//  XiangShan Difftest
//------------------------------------------------------------------------------
    reg                      cmt_wen                    ;
    reg     [   7:0]         cmt_wdest                  ;
    reg     [`REG_BUS]       cmt_wdata                  ;
    reg     [`REG_BUS]       cmt_pc,cmt_done_pc         ;
    reg     [  31:0]         cmt_inst                   ;
    reg                      cmt_valid                  ;
    reg                      cmt_skip                   ;
    reg                      trap                       ;
    reg     [   7:0]         trap_code                  ;
    reg     [  63:0]         cycleCnt                   ;
    reg     [  63:0]         instrCnt                   ;
    reg     [`REG_BUS]       regs_diff_npc [0:31]       ;
    reg     [`DATA_WIDTH-1:0]cmt_intrNO                 ;
    wire                     real_cmt = (wb_diff_pc != `PC_WIDTH'b0) && (wb_diff_pc != `PC_WIDTH'b1) && (wb_inst != `INST_WIDTH'b0) && wbu_valid_o_next && wbu_ready
                                        && (wb_diff_pc != cmt_wb_diff_pc)&& !iru_intr;//一条指令不能提交两遍

  assign s_uart_out_valid = real_cmt & (cmt_inst == `DATA_WIDTH'h7b);
  assign s_uart_out_char = regs[10][7:0];

  wire csr_mcycle = real_cmt & (cmt_inst[6: 0] == `INST_CSR & cmt_inst[31:20] == `ADDR_CSR_MCYCLE);
  wire cmt_skip = s_uart_out_valid | csr_mcycle | wb_clint_ldst;

//commit need 
//assign real_cmt = (wb_diff_pc != `PC_WIDTH'b0) && (wb_inst != `INST_WIDTH'b0) && fetched && mem_lsu_valid;


//initial begin
//    $monitor("cmt_wdest is %h",cmt_wdest);
//    $monitor("cmt_wdata is %h",cmt_wdata);
//end
//record have cmt PC value for flush residual
logic [`PC_WIDTH-1:0] cmt_wb_diff_pc;
always @(posedge clk) begin
  if (!rst_n) begin
  end
  else if(cmt_valid)begin
    cmt_wb_diff_pc <= wb_diff_pc;
  end
end



always @(negedge clk) begin
  if (!rst_n) begin
    {cmt_wen, cmt_wdest, cmt_wdata, cmt_pc, cmt_inst, cmt_valid, cmt_intrNO, trap, trap_code, cycleCnt, instrCnt} <= 0;
  end
  else if (~trap) begin
    cmt_wen   <= wb_reg_wen;                                        //rd_w_ena;
    cmt_wdest <= {3'd0, wb_reg_waddr};                              //{3'd0, rd_w_addr};
    cmt_wdata <= wb_reg_wdata;                                      //rd_data;
    cmt_pc <= wb_diff_pc;                                           //pc;
    cmt_inst <= wb_inst;                                            //inst;
    cmt_valid <= real_cmt;                                          //real_cmt;
    cmt_intrNO <=(iru_intr & wbu_ready) ? s_mcause : 0;             // 中断号，非0时产生中断。产生中断的时钟周期中，DifftestInstrCommit提交的valid需为0
    regs_diff_npc <= regs         ;

    trap <= wb_inst[6:0] == 7'h6b;
    trap_code <= regs[10][7:0];
    cycleCnt <= cycleCnt + 1;
    instrCnt <= instrCnt + real_cmt;
  end
end

DifftestInstrCommit DifftestInstrCommit(
    .clock                             (clk                       ),
    .coreid                            (0                         ),
    .index                             (0                         ),
    .valid                             (cmt_valid                 ),
    .pc                                (cmt_pc                    ),
    .instr                             (cmt_inst                  ),
    .skip                              (cmt_skip                  ),
    .isRVC                             (0                         ),
    .scFailed                          (0                         ),
    .wen                               (cmt_wen                   ),
    .wdest                             (cmt_wdest                 ),
    .wdata                             (cmt_wdata                 ) 
);

DifftestArchIntRegState DifftestArchIntRegState (
    .clock                             (clk                       ),
    .coreid                            (0                         ),
    .gpr_0                             (regs_diff_npc[0]          ),
    .gpr_1                             (regs_diff_npc[1]          ),
    .gpr_2                             (regs_diff_npc[2]          ),
    .gpr_3                             (regs_diff_npc[3]          ),
    .gpr_4                             (regs_diff_npc[4]          ),
    .gpr_5                             (regs_diff_npc[5]          ),
    .gpr_6                             (regs_diff_npc[6]          ),
    .gpr_7                             (regs_diff_npc[7]          ),
    .gpr_8                             (regs_diff_npc[8]          ),
    .gpr_9                             (regs_diff_npc[9]          ),
    .gpr_10                            (regs_diff_npc[10]         ),
    .gpr_11                            (regs_diff_npc[11]         ),
    .gpr_12                            (regs_diff_npc[12]         ),
    .gpr_13                            (regs_diff_npc[13]         ),
    .gpr_14                            (regs_diff_npc[14]         ),
    .gpr_15                            (regs_diff_npc[15]         ),
    .gpr_16                            (regs_diff_npc[16]         ),
    .gpr_17                            (regs_diff_npc[17]         ),
    .gpr_18                            (regs_diff_npc[18]         ),
    .gpr_19                            (regs_diff_npc[19]         ),
    .gpr_20                            (regs_diff_npc[20]         ),
    .gpr_21                            (regs_diff_npc[21]         ),
    .gpr_22                            (regs_diff_npc[22]         ),
    .gpr_23                            (regs_diff_npc[23]         ),
    .gpr_24                            (regs_diff_npc[24]         ),
    .gpr_25                            (regs_diff_npc[25]         ),
    .gpr_26                            (regs_diff_npc[26]         ),
    .gpr_27                            (regs_diff_npc[27]         ),
    .gpr_28                            (regs_diff_npc[28]         ),
    .gpr_29                            (regs_diff_npc[29]         ),
    .gpr_30                            (regs_diff_npc[30]         ),
    .gpr_31                            (regs_diff_npc[31]         ) 
);

DifftestTrapEvent DifftestTrapEvent(
    .clock                             (clk                       ),
    .coreid                            (0                         ),
    .valid                             (trap                      ),
    .code                              (trap_code                 ),
    .pc                                (cmt_pc                    ),
    .cycleCnt                          (cycleCnt                  ),
    .instrCnt                          (instrCnt                  ) 
);

DifftestCSRState DifftestCSRState(
    .clock                             (clk                       ),
    .coreid                            (0                         ),
    .priviledgeMode                    (`RISCV_PRIV_MODE_M        ),
    .mstatus                           (s_mstatus                 ),
    .sstatus                           (s_sstatus                 ),
    .mepc                              (s_mepc                    ),
    .sepc                              (0                         ),
    .mtval                             (0                         ),
    .stval                             (0                         ),
    .mtvec                             (s_mtvec                   ),
    .stvec                             (0                         ),
    .mcause                            (s_mcause                         ),
    .scause                            (0                  ),
    .satp                              (0                         ),
    .mip                               (0                         ),//s_mip
    .mie                               (s_mie                     ),//s_mie，挂起中断会报错，定位difftest有问题
    .mscratch                          (s_mscratch                ),
    .sscratch                          (0                         ),
    .mideleg                           (0                         ),
    .medeleg                           (0                         ) 
);
  
DifftestArchEvent DifftestArchEvent (
    .clock                             (clk                       ),
    .coreid                            (0                         ),
    .intrNO                            (cmt_intrNO                ),// 中断号，非0时产生中断。产生中断的时钟周期中，DifftestInstrCommit提交的valid需为0
    .cause                             (0                         ),// 异常号，ecall时不需要考虑
    .exceptionPC                       (cmt_pc                    ),// except PC value
    .exceptionInst                     (cmt_inst                  ) // except inst
  );

DifftestArchFpRegState DifftestArchFpRegState(
    .clock                             (clk                       ),
    .coreid                            (0                         ),
    .fpr_0                             (0                         ),
    .fpr_1                             (0                         ),
    .fpr_2                             (0                         ),
    .fpr_3                             (0                         ),
    .fpr_4                             (0                         ),
    .fpr_5                             (0                         ),
    .fpr_6                             (0                         ),
    .fpr_7                             (0                         ),
    .fpr_8                             (0                         ),
    .fpr_9                             (0                         ),
    .fpr_10                            (0                         ),
    .fpr_11                            (0                         ),
    .fpr_12                            (0                         ),
    .fpr_13                            (0                         ),
    .fpr_14                            (0                         ),
    .fpr_15                            (0                         ),
    .fpr_16                            (0                         ),
    .fpr_17                            (0                         ),
    .fpr_18                            (0                         ),
    .fpr_19                            (0                         ),
    .fpr_20                            (0                         ),
    .fpr_21                            (0                         ),
    .fpr_22                            (0                         ),
    .fpr_23                            (0                         ),
    .fpr_24                            (0                         ),
    .fpr_25                            (0                         ),
    .fpr_26                            (0                         ),
    .fpr_27                            (0                         ),
    .fpr_28                            (0                         ),
    .fpr_29                            (0                         ),
    .fpr_30                            (0                         ),
    .fpr_31                            (0                         ) 
);

endmodule


