`include "vsrc/rvseed_defines.sv"

module mux_alu( 
    input      [`ALU_SRC_WIDTH-1:0] alu_src_sel,// reg or imm to alu

    input      [`DATA_WIDTH-1:0]     reg1_rdata, // register 1 read data
    input      [`DATA_WIDTH-1:0]     reg2_rdata, // register 2 read data
    input      [`DATA_WIDTH-1:0]     imm,        // immediate
    input      [`PC_WIDTH-1:0]      curr_pc,    // current pc addr
/*
    input  [`DATA_WIDTH-1:0]     alu_src1_ex_mem,   //bypass
    input  [`DATA_WIDTH-1:0]     alu_src1_mem_wb, 
    input  [`DATA_WIDTH-1:0]     alu_src2_ex_mem,   
    input  [`DATA_WIDTH-1:0]     alu_src2_mem_wb, */

    output logic [`DATA_WIDTH-1:0]     alu_src1,   // alu source 1
    output logic [`DATA_WIDTH-1:0]     alu_src2    // alu source 2
);
    //logic [`DATA_WIDTH-1:0]  alu_src1, alu_src2;

	
always @(*) begin
    alu_src1 = reg1_rdata;     // defalut select reg1 data
    alu_src2 = reg2_rdata;     // default select reg2 data
    case (alu_src_sel)
        `ALU_SRC_REG: 
            alu_src2 = reg2_rdata; // select reg2 data
        `ALU_SRC_IMM: 
            alu_src2 = imm;        // select immediate 
        `ALU_SRC_FOUR_PC: begin
            alu_src1 = `PC_WIDTH'h4; // pc + 4 
            alu_src2 = curr_pc;       //
        end
        `ALU_SRC_IMM_PC: begin //select imm and pc
            alu_src1 = imm;
            alu_src2 = curr_pc;
        end
        default:;
    endcase
end





endmodule
