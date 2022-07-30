`include "rvseed_defines.sv"
module if_stage(
    input                               clk,
    input                               rst_n,
//interface for oscpu

	output if_valid,
	input  if_ready,
    input  [63:0] if_data_read,
    output logic [63:0] if_addr,
    output [1:0] if_size,
    input  [1:0] if_resp,
    output reg fetched,

//for mux_pc
    //input  logic   [`PC_WIDTH-1 : 0]         curr_pc, 
//for bpu
    input  logic   [`PC_WIDTH-1:0]     ex_pc,
    input  logic                       ex_branch,                          // ex_branch type 
    input  logic                       ex_zero,                           // alu result is ex_zero
    input  logic                       ex_jump,                            // ex_jump type 
    input  logic   [`DATA_WIDTH-1:0]   ex_imm,                            // immediate  
    input  logic   [`DATA_WIDTH-1:0]   ex_reg1_rdata,                     // rs1    ex_jalr:rs1+ex_imm
    input  logic                       ex_jalr,
//from data_bypass
    input  logic                       bubble_id_ex,
//if_id need
    output logic       [`INST_WIDTH-1:0]           if_inst  ,
    output logic       [`PC_WIDTH-1:0]             if_pc    , 
    output        [`PC_WIDTH-1:0]             next_pc,  // current pc addr
    output logic                       bpu_bubble,
    
//handshake signal
    input  ready_next_i,
    output valid_o_next
);
//fetch an instruction
wire handshake_done = if_valid & if_ready;
reg [63:0] addr;

// fetch an instruction
always @( posedge clk ) begin
  if (!rst_n) begin
    if_pc <= `PC_START;
    //if_addr <= `PC_START;
    fetched <= 0;
  end
  
  else if ( handshake_done) begin
    if_pc <= next_pc;
    //if_addr <= next_pc + 4;
    fetched <= 1;
    if_inst <= if_data_read[31:0];
  end
  else begin
    fetched <= 0;
  end
end
assign if_addr = (!rst_n) ? `PC_START : next_pc;//update inst from if_addr need sync with if_pc
assign if_valid = 1'b1;
assign if_size = `SIZE_W;

    //assign if_pc = curr_pc ;
    
//------------------------------------------------------------------------------
//  1.IF 
//------------------------------------------------------------------------------
    logic   [`PC_WIDTH-1:0]     bpu_pc_update;
    logic                       pc_add_imm_flag;//jump flag
bpu u_bpu(
    .ex_pc                             (ex_pc                     ),
    .ex_branch                         (ex_branch                 ),
    .ex_zero                           (ex_zero                   ),
    .ex_jump                           (ex_jump                   ),
    .ex_imm                            (ex_imm                    ),
    .ex_reg1_rdata                     (ex_reg1_rdata             ),
    .ex_jalr                           (ex_jalr                   ),

    .pc_add_imm_flag                   (pc_add_imm_flag           ),
    .bpu_pc_update                     (bpu_pc_update             ),
    .bubble                            (bpu_bubble                ) 
);

    logic   [`PC_WIDTH-1:0]     curr_pc_update;
mux_pc u_mux_pc(
    .curr_pc                           (if_pc                   ),
    .bpu_pc_update                     (bpu_pc_update             ),
    .pc_add_imm_flag                   (pc_add_imm_flag           ),
    
    .curr_pc_update                    (curr_pc_update            ) 
);

    logic                       pc_wen = ~bubble_id_ex && (ready_next_i && valid_o_next);//shake success and not insert bubble
    
pc_update u0_pc_update(
    .clk                               (clk                       ),// system clock
    .rst_n                             (rst_n                     ),// active low reset
    .pc_wen                            (pc_wen                    ),// system enable
    .curr_pc_update                    (curr_pc_update            ),// current pc addr

    .next_pc                           (next_pc                   ) // used for DPIC INST Fetch
);

//------------------------------------------------------------------------------
//  IF-ID HANDSHAKE 
//------------------------------------------------------------------------------
//handshake
logic valid_o_next_r;
assign valid_o_next = valid_o_next_r && fetched; 
pipehandshake u_if_id_handshake(
    .clk          ( clk          ),
    .rst_n        ( rst_n        ),
    .valid_pre_i  ( 1  ),//for valid_o_next
    .ready_next_i ( ready_next_i ),

    .valid_o_next ( valid_o_next_r ),
    .ready_o_pre  (  )
);

endmodule