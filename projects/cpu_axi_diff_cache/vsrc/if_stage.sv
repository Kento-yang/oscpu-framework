`include "rvseed_defines.sv"
module if_stage(
    input                               clk,
    input                               rst_n,
    input logic                         icache_hit,
    input logic                         hit,
    input logic                         hit_r,
    input logic                         flush,
//interface for icache
    output                              if_valid                   ,
    input                               if_ready                   ,
    input        [`AXI_DATA_WIDTH:0]    if_data_read               ,
    output logic [`AXI_ADDR_WIDTH-1:0]  if_addr                    ,
    output             [   1:0]         if_size                    ,
    input              [   1:0]         if_resp                    ,
    output logic                        fetched                    ,//for difftest
//for mux_pc
    //input  logic   [`PC_WIDTH-1 : 0]         curr_pc, 
//from iru
    input  logic                        iru_excp   ,//ecall/mret
    input  logic                        iru_intr   ,//timer
    input  logic [`DATA_WIDTH-1:0]      iru_pc     ,
//from iru
    input logic mret,
//for bpu
    input  logic   [`PC_WIDTH-1:0]      ex_pc,
    input  logic                        ex_branch,                          // ex_branch type 
    input  logic                        ex_zero,                           // alu result is ex_zero
    input  logic                        ex_jump,                            // ex_jump type 
    input  logic   [`DATA_WIDTH-1:0]    ex_imm,                            // immediate  
    input  logic   [`DATA_WIDTH-1:0]    ex_reg1_rdata,                     // rs1    ex_jalr:rs1+ex_imm
    input  logic                        ex_jalr,
//from data_bypass 
    input  logic                        bubble_id_ex,
//if_id need
    output logic  [`INST_WIDTH-1:0]     if_inst   ,
    output logic  [`PC_WIDTH-1:0]       if_pc     , 
    output        [`PC_WIDTH-1:0]       next_pc   ,  // current pc addr
    output logic                        bpu_bubble,
//handshake signal
    input                               ready_id2if,
    output                              valid_if2id
);
//shake hands to AXI -- IF for store INST (grant = 1 may be flush the pre if inst)
  logic [`INST_WIDTH-1:0] if_data_read_i, if_data_read_r;
  assign if_data_read_i = if_data_read[`INST_WIDTH-1:0];

Reg #(
    .WIDTH      (`INST_WIDTH),
    .RESET_VAL  (`INST_WIDTH'b0)
  ) if_id_reg(
  	.clk      (clk                ),
    .rst_n    (rst_n              ),
    .wen      (axi_if_handshake_done ),
    .din      (if_data_read_i),
    .dout     (if_data_read_r)
  );
  //hit first cycle out inst is always error because of sram rd need 1 cycle!!!
  assign if_inst = (axi_if_handshake_done && !(hit && !hit_r) )? if_data_read_i : if_data_read_r;


  logic ex_jump_flag_r;
  always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
      ex_jump_flag_r <= 0;
    else
      ex_jump_flag_r <= ex_jump_flag;//generate next_pc need ex_jump_flag delay 1 cycle.
  end
//fetch an instruction
wire axi_if_handshake_done = if_valid & if_ready;
reg [63:0] addr;
//if mret, 
//1.need to bubble the next inst use iru_jmp_cnt.
//2.need to keep the mepc use iru_jmp_cnt until iru_jmp_cnt == 0.
logic [1:0] iru_jmp_cnt;

// fetch an instruction
//1. mret/jump separare discuss because of the mret next pc update now,jump next_pc
always @( posedge clk ) begin
  if (!rst_n) begin
    if_pc <= `PC_START;
    if_addr <= `PC_START;
    fetched <= 0;
    iru_jmp_cnt <= 2'b00;
  end
  else if (iru_excp || iru_intr || ex_jump_flag_r) /*&& icache_hit*/begin//have jump addr const.
    //if_inst <= if_data_read_r;
    if_pc <= next_pc;
    if_addr <= next_pc;
    //iru_jmp_cnt <= iru_jmp_cnt + 1;
    fetched <= 0;
  end
  else if ( axi_if_handshake_done && !(iru_excp || iru_intr || ex_jump_flag) && icache_hit  && (valid_if2id & ready_id2if) && !bubble_id_ex) begin//no jump, read common
    //if_inst <= if_data_read_i;
    if_pc <= if_addr;
    if_addr <= if_addr + 4;
    //iru_jmp_cnt <= 2'b00;
    fetched <= 1;
  end
  else if(ex_jump_flag && !ex_jump_flag_r)begin
    if_pc <= 0;
    //iru_jmp_cnt <= 2'b00;
    fetched <= 0;
  end
  else if(!icache_hit)begin//miss,record now if_pc and fetch from axi.
    if_pc <= if_pc;
    if_addr <= if_addr;
    fetched <= 0;
  end
  //else begin
    //if_inst <= if_data_read_r;
  //  if_pc <= if_addr;
  //  if_addr <= if_addr;
  //  fetched <= 0;
  //end
    //if_inst <= if_data_read[31:0];
end

//assign if_addr = (!rst_n) ? `PC_START : next_pc;//update inst from if_addr need sync with if_pc
assign if_valid = 1 ;
assign if_size = `SIZE_W;

    //assign if_pc = curr_pc ;


// maintain for branch/jump, while ex judge jump occer, need make IF fetch inst again.
// 1、EX need JUMP
// 2、add bubble
// 3、fetch inst again
/*logic [1:0] jump_cnt;
always @( posedge clk ) begin
  if (!rst_n) begin
    jump_cnt <= 2'b0 ;
  end
  else if(jump_cnt == 1 && axi_if_handshake_done)begin
    jump_cnt <= 2'b0 ;
  end
  else if((ex_jump_flag || iru_excp || iru_intr ) && axi_if_handshake_done )begin
    jump_cnt <= jump_cnt + 1;
  end
end*/

//------------------------------------------------------------------------------
//  1.IF 
//------------------------------------------------------------------------------
    logic   [`PC_WIDTH-1:0]     bpu_pc_update;
    logic                       ex_jump_flag;//jump flag
//comb for jump pc from ex stage ,and generate bpu bubble.
bpu u_bpu(
    .ex_pc                             (ex_pc                     ),
    .ex_branch                         (ex_branch                 ),
    .ex_zero                           (ex_zero                   ),
    .ex_jump                           (ex_jump                   ),
    .ex_imm                            (ex_imm                    ),
    .ex_reg1_rdata                     (ex_reg1_rdata             ),
    .ex_jalr                           (ex_jalr                   ),
    .iru_excp                          (iru_excp                  ),
    .flush                             (flush                     ),

    .pc_add_imm_flag                   (ex_jump_flag              ),
    .bpu_pc_update                     (bpu_pc_update             ),
    .bubble                            (bpu_bubble                ) 
);

    logic   [`PC_WIDTH-1:0]     curr_pc_update;
mux_pc u_mux_pc(
    .curr_pc                           (if_pc                   ),
    .bpu_pc_update                     (bpu_pc_update             ),
    .pc_add_imm_flag                   (ex_jump_flag           ),
    
    .curr_pc_update                    (curr_pc_update            ) 
);

    wire                       pc_wen = /*~bubble_id_ex &&*/ ((ready_id2if || ex_jump_flag) && valid_if2id);//shake success and not insert bubble
    logic        [`PC_WIDTH-1:0]             next_pc_r;  // current pc addr
pc_update u0_pc_update(
    .clk                               (clk                       ),// system clock
    .rst_n                             (rst_n                     ),// active low reset
    .pc_wen                            (pc_wen                    ),// system enable
    .curr_pc_update                    (curr_pc_update            ),// current pc addr

    .next_pc                           (next_pc_r                   ) // used for  INST Fetch
);

assign next_pc = (iru_excp | iru_intr) ? iru_pc : next_pc_r;

//------------------------------------------------------------------------------
//  IF-ID HANDSHAKE 
//------------------------------------------------------------------------------
//handshake
logic valid_o_next_r;
assign valid_if2id = valid_o_next_r && (axi_if_handshake_done || ex_jump_flag);//(fetched || ex_jump_flag); 
pipehandshake u_if_id_handshake(
    .clk          ( clk            ),
    .rst_n        ( rst_n          ),
    .valid_pre_i  ( flush ? 0 : 1  ),//for valid_if2id
    .ready_next_i ( ready_id2if ),

    .valid_o_next ( valid_o_next_r ),
    .ready_o_pre  (  )
);

endmodule