`include "vsrc/rvseed_defines.sv"

module mux_pc (
    input  logic    [`PC_WIDTH-1:0]     curr_pc,
    input  logic    [`PC_WIDTH-1:0]     bpu_pc_update,
    input  logic                        pc_add_imm_flag,

    output logic    [`PC_WIDTH-1:0]     curr_pc_update  
);


assign curr_pc_update = pc_add_imm_flag ? bpu_pc_update :  (curr_pc + `DATA_WIDTH'h4);//stage ex(pc+imm/reg1+imm) or if(pc+4)


endmodule
