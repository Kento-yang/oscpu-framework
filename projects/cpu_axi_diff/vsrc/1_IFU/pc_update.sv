`include "vsrc/rvseed_defines.sv"

module pc_update (
    input                               clk,     // system clock
    input                               rst_n,   // active low reset
    input                               pc_wen,     // system enable
    input           [`PC_WIDTH-1:0]     curr_pc_update, // next pc addr
    
    output logic    [`PC_WIDTH-1:0]     next_pc  // current pc addr
);

Reg#(
    .WIDTH ( `PC_WIDTH ),
    .RESET_VAL ( `PC_WIDTH'h80000000 )
)u_pc_update_Reg(
    .clk   ( clk   ),
    .rst_n ( rst_n ),
    .din   ( curr_pc_update   ),
    .wen   ( pc_wen   ),
    .dout  ( next_pc  )
);

endmodule
