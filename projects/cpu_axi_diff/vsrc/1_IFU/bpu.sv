module bpu (
    input           [`PC_WIDTH-1:0]     ex_pc,
    input                               ex_branch,  // ex_branch type 
    input                               ex_zero,    // alu result is ex_zero
    input                               ex_jump,    // ex_jump type 
    input           [`DATA_WIDTH-1:0]   ex_imm,     // immediate  
    input           [`DATA_WIDTH-1:0]   ex_reg1_rdata,     // rs1    ex_jalr:rs1+ex_imm
    input                               ex_jalr,

    output logic                        pc_add_imm_flag,
    output logic    [`PC_WIDTH-1:0]     bpu_pc_update,
    output logic                        bubble
);

assign pc_add_imm_flag = ((ex_branch && ~ex_zero) || ex_jump )? 1 : 0;//bne or ex_jump

assign bpu_pc_update =  ex_jalr ? ((ex_reg1_rdata + ex_imm) &(~1)): (ex_pc + ex_imm);

assign bubble = pc_add_imm_flag;//if ex_jump/ex_branch make nop for if_id and id_ex

endmodule
