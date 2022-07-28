`include "vsrc/rvseed_defines.sv"

module imm_gen (
    input      [`INST_WIDTH-1:0]        inst,       // instruction input
    input      [`IMM_GEN_OP_WIDTH-1:0] imm_gen_op, // immediate extend opcode

    output reg [`DATA_WIDTH-1:0]        imm         // immediate  
);

always @(*) begin
    imm = 64'b0;
    case (imm_gen_op)// all 64bit
        //Rtype no imm
        `IMM_GEN_I:
             imm = {{52{inst[31]}},inst[31:20]};
        `IMM_GEN_S:
             imm = {{52{inst[31]}},inst[31:25],inst[11:7]};
        `IMM_GEN_B:
             imm = {{52{inst[31]}},inst[7],inst[30:25],inst[11:8], 1'b0};
        `IMM_GEN_J:
             imm = {{44{inst[31]}},inst[19:12],inst[20],inst[30:21], 1'b0};
        `IMM_GEN_U:
             imm = {{32{inst[31]}},inst[31:12],12'b0};

        default:;
    endcase
end

endmodule
