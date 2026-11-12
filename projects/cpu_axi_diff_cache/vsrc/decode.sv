`include "rvseed_defines.sv"
//ebreak
//0000000 00001 00000 000 00000 11100 11
module decode (
    input  logic      [`INST_WIDTH-1 : 0]         inst,       // instruction input

    output logic                                  branch,     // branch flag
    output logic                                  jump,       // jump flag

    output logic                                  reg_wen,    // register write enable
    output logic      [`REG_ADDR_WIDTH-1 : 0]     reg_waddr,  // register write address
    output logic      [`REG_ADDR_WIDTH-1 : 0]     reg1_raddr, // register 1 read address
    output logic      [`REG_ADDR_WIDTH-1 : 0]     reg2_raddr, // register 2 read address
//to csr
    output logic      [`CSR_ADDR_WIDTH-1 : 0]     csr_raddr,      //读CSR寄存器地址
    output logic                                  csr_ren,      //读CSR寄存器地址

    output logic                                  csr_wen,                     // 写CSR寄存器标志
    output logic      [`CSR_ADDR_WIDTH-1 : 0]     csr_waddr,     // 写CSR寄存器地址
    output logic      [`CSR_IMM_WIDTH -1:0]       csr_zimm,     // 写CSR寄存器地址
    
    output logic      [`IMM_GEN_OP_WIDTH-1 : 0]   imm_gen_op, // immediate extend opcode

    output logic      [`ALU_OP_WIDTH-1 : 0]       alu_op,     // alu opcode
    output logic      [`ALU_SRC_WIDTH-1 : 0]      alu_src_sel, // alu source select flag
    
    output logic    [`LSU_OPT_WIDTH-1 : 0]      lsu_opt,
    output logic                                lsu_lden,
    output logic                                lsu_sten,
    output logic                                jalr           
);

wire [`OPCODE_WIDTH-1:0]    opcode = inst[`OPCODE_WIDTH-1:0];//[6:0]            
wire [`FUNCT3_WIDTH-1:0]    funct3 = inst[`FUNCT3_WIDTH+`FUNCT3_BASE-1:`FUNCT3_BASE];//[14:12]
wire [`FUNCT7_WIDTH-1:0]    funct7 = inst[`FUNCT7_WIDTH+`FUNCT7_BASE-1:`FUNCT7_BASE];//[31:25] R-type
wire [`REG_ADDR_WIDTH-1:0]  rd     = inst[`REG_ADDR_WIDTH+`RD_BASE-1:`RD_BASE];//[11:7] 
wire [`REG_ADDR_WIDTH-1:0]  rs1    = inst[`REG_ADDR_WIDTH+`RS1_BASE-1:`RS1_BASE];//[19:15]
//wire [`REG_ADDR_WIDTH-1:0]  uimm   = inst[`REG_ADDR_WIDTH+`RS1_BASE-1:`RS1_BASE];//[19:15] CSR IMM
wire [`REG_ADDR_WIDTH-1:0]  rs2    = inst[`REG_ADDR_WIDTH+`RS2_BASE-1:`RS2_BASE];//[24:20]

//wire [`ITYPE_SHAMT-1:0]     I_type_shamt  = inst[25:20];//[25:20]
//inst type decode,use opcode[6:0]

assign csr_ren =  ((opcode == `INST_CSR) && (funct3 == `INST_CSRRW) || (funct3 == `INST_CSRRWI)) ||
                   (funct3 == `INST_CSRRS) || (funct3 == `INST_CSRRC) || (funct3 == `INST_CSRRSI) || (funct3 == `INST_CSRRCI);
    
//==============1.REG INFO DECODE==============
  always@(*)begin
    reg1_raddr  = `REG_ADDR_WIDTH'b0;
    reg2_raddr  = `REG_ADDR_WIDTH'b0;
    reg_waddr   = `REG_ADDR_WIDTH'b0;
    reg_wen     = 1'b0;
    csr_wen     = 1'b0; //CSR
    csr_raddr   = inst[31:20];//CSR
    csr_waddr   = inst[31:20];//CSR
    csr_zimm    = inst[19:15];//CSR
    case(opcode)    
      `INST_TYPE_R: begin   reg1_raddr = rs1;  reg2_raddr = rs2;  reg_waddr = rd;  reg_wen = 1'b1; end
      `INST_TYPE_I: begin   reg1_raddr = rs1;                     reg_waddr = rd;  reg_wen = 1'b1; end
      `INST_TYPE_IL:begin   reg1_raddr = rs1;                     reg_waddr = rd;  reg_wen = 1'b1; end
      `INST_TYPE_S: begin   reg1_raddr = rs1;  reg2_raddr = rs2;                                   end
      `INST_TYPE_B: begin   reg1_raddr = rs1;  reg2_raddr = rs2;                                   end
      `INST_JAL:    begin                                         reg_waddr = rd;  reg_wen = 1'b1; end
      `INST_JALR:   begin   reg1_raddr = rs1;                     reg_waddr = rd;  reg_wen = 1'b1; end
      `INST_LUI:    begin                                         reg_waddr = rd;  reg_wen = 1'b1; end //LUI: rd = x0 + imm;
      `INST_AUIPC:  begin                                         reg_waddr = rd;  reg_wen = 1'b1; end
      `INST_TYPE_RW:begin   reg1_raddr = rs1;  reg2_raddr = rs2;  reg_waddr = rd;  reg_wen = 1'b1; end
      `INST_TYPE_IW:begin   reg1_raddr = rs1;                     reg_waddr = rd;  reg_wen = 1'b1; end
      //CSR
      `INST_CSR:begin   case (funct3)
                            `INST_CSRRW, `INST_CSRRS, `INST_CSRRC: 
                                begin reg1_raddr = rs1; reg_wen = 1'b1;  reg_waddr = rd; csr_wen = 1'b1;  end
                            `INST_CSRRWI, `INST_CSRRSI, `INST_CSRRCI: 
                                begin                   reg_wen = 1'b1;  reg_waddr = rd; csr_wen = 1'b1;  end
                            default:;
                        endcase 
                end
    default:;
    endcase
  end

//===============2.IMM INFO DECODE===============
  always@(*)begin
    imm_gen_op  = `IMM_GEN_I;
    case(opcode)    
      `INST_TYPE_S:  imm_gen_op  = `IMM_GEN_S;
      `INST_TYPE_B:  imm_gen_op  = `IMM_GEN_B;
      `INST_JAL:     imm_gen_op  = `IMM_GEN_J;
      `INST_LUI:     imm_gen_op  = `IMM_GEN_U;
      `INST_AUIPC:   imm_gen_op  = `IMM_GEN_U;
      default:       imm_gen_op  = `IMM_GEN_I;//TYPE I/IL/IW/JALR   R/RW no imm
    endcase
  end

//=============3.ALU INFO DECODE================
  always @(*) begin
    alu_op      = `ALU_AND;
    alu_src_sel = `ALU_SRC_REG;
    case (opcode)
    //=================RV32I=====================
    //---------R-TYPE--------
        `INST_TYPE_R: begin alu_src_sel = `ALU_SRC_REG;
            case (funct3)
                `INST_ADD_SUB_MUL:
                    case(funct7)
                        `FUNCT7_INST_A:alu_op = `ALU_ADD; 
                        `FUNCT7_INST_B:alu_op = `ALU_SUB;
                        `FUNCT7_INST_RV_M: alu_op = `ALU_MUL;
                        default:;
                    endcase
                `INST_XOR:
                    case(funct7)
                        `FUNCT7_INST_A: alu_op = `ALU_XOR;
                        `FUNCT7_INST_B:;
                        `FUNCT7_INST_RV_M: alu_op = `ALU_DIV;
                        default:;
                    endcase 
                `INST_OR: 
                    case(funct7)
                        `FUNCT7_INST_A: alu_op = `ALU_OR;
                        `FUNCT7_INST_B:;
                        `FUNCT7_INST_RV_M: alu_op = `ALU_REM;
                        default:;
                    endcase 
                `INST_AND:
                    case(funct7)
                        `FUNCT7_INST_A: alu_op = `ALU_AND;
                        `FUNCT7_INST_B:;
                        `FUNCT7_INST_RV_M: alu_op = `ALU_REMU;
                        default:;
                    endcase 
                `INST_SLL:
                    case(funct7)
                        `FUNCT7_INST_A:alu_op = `ALU_SLL;
                        `FUNCT7_INST_B:;
                        `FUNCT7_INST_RV_M: alu_op = `ALU_MULH;
                        default:;
                    endcase 
                `INST_SRL_SRA:
                    case(funct7)
                        `FUNCT7_INST_A:alu_op = `ALU_SRL;
                        `FUNCT7_INST_B:alu_op = `ALU_SRA;
                        `FUNCT7_INST_RV_M: alu_op = `ALU_DIVU;
                        default:;
                    endcase 
                `INST_SLT:
                    case(funct7)
                        `FUNCT7_INST_A: alu_op = `ALU_SLT;
                        `FUNCT7_INST_B:;
                        `FUNCT7_INST_RV_M: alu_op = `ALU_MULSU;
                        default:;
                    endcase 
                `INST_SLTU:
                    case(funct7)
                        `FUNCT7_INST_A: alu_op = `ALU_SUBU;
                        `FUNCT7_INST_B:;
                        `FUNCT7_INST_RV_M: alu_op = `ALU_MULU;
                        default:;
                    endcase 
                default:;
            endcase 
        end
        //---------I-TYPE--------
        `INST_TYPE_I: begin alu_src_sel = `ALU_SRC_IMM;
            case (funct3)
                `INST_ADDI:alu_op = `ALU_ADD; //addi
                `INST_XORI:alu_op = `ALU_XOR;
                `INST_ORI:alu_op = `ALU_OR;
                `INST_ANDI:alu_op = `ALU_AND;
                //rv64i
                `INST_SLLI:alu_op = `ALU_SLL;
                `INST_SRLI_SRAI:
                    case(funct7)
                        `FUNCT7_INST_A: alu_op = `ALU_SRL;//funct7=00 caution shamt!
                        `FUNCT7_INST_B: alu_op =`ALU_SRA;//20
                        `FUNCT7_INST_RV_M: alu_op = `ALU_SRL;//01
                        default:    alu_op =`ALU_SRA;//21
                    endcase 
                //finish rv64i
                `INST_SLTI:alu_op = `ALU_SLT;
                `INST_SLTIU:alu_op = `ALU_SUBU;
                default:;   
            endcase
        end
        //---------I-LD-TYPE--------
        `INST_TYPE_IL: begin //load 
            alu_op = `ALU_ADD; 
            alu_src_sel = `ALU_SRC_IMM;//x0 + imm  
        end
        //---------S-TYPE--------
        `INST_TYPE_S:  begin //store 
            alu_op = `ALU_ADD; 
            alu_src_sel = `ALU_SRC_IMM; //x0 + imm
        end
        //---------B-TYPE--------
        `INST_TYPE_B: begin alu_src_sel = `ALU_SRC_REG;
            case (funct3)
                `INST_BEQ: alu_op = `ALU_BEQ;
                `INST_BNE: alu_op = `ALU_SUB;
                `INST_BLT: alu_op = `ALU_BLT;
                `INST_BGE: alu_op = `ALU_BGE;
                `INST_BLTU:alu_op = `ALU_BLTU;
                `INST_BGEU:alu_op = `ALU_BGEU;
                default:;
            endcase
        end
        //---------jal--------
        `INST_JAL: begin // only jal
            alu_op      = `ALU_ADD;
            alu_src_sel = `ALU_SRC_FOUR_PC; //pc + 4
        end
        //---------jalr--------
        `INST_JALR:begin// only jalr
            alu_op      = `ALU_ADD;
            alu_src_sel = `ALU_SRC_FOUR_PC; //pc + 4
        end
        //============U type===========
        `INST_LUI: begin // only lui
            alu_op      = `ALU_ADD;
            alu_src_sel = `ALU_SRC_IMM; // x0 + imm
        end
        `INST_AUIPC: begin // only auipc
            alu_op      = `ALU_ADD;
            alu_src_sel = `ALU_SRC_IMM_PC; // pc + imm
        end
        //`INST_ECALL:DPIC
        //`INST_EBREAK:DPIC
    //=================RV64I/M=====================
        `INST_TYPE_RW: begin alu_src_sel = `ALU_SRC_REG;
            case (funct3)
                `INST_ADD_SUB_MUL: //addw subw
                    case(funct7)
                        `FUNCT7_INST_A:alu_op = `ALU_ADDW;
                        `FUNCT7_INST_B:alu_op = `ALU_SUBW;
                        `FUNCT7_INST_RV_M: alu_op = `ALU_MULW;
                        default:;
                    endcase 
                `INST_DIVW: alu_op = `ALU_DIVW;
                `INST_REMW: alu_op = `ALU_REMW;
                `INST_SLL:  alu_op = `ALU_SLLW;//sllw
                `INST_SRLW_SRAW: 
                    case(funct7)
                        `FUNCT7_INST_A:alu_op = `ALU_SRLW;
                        `FUNCT7_INST_B:alu_op = `ALU_SRAW;
                        `FUNCT7_INST_RV_M:;
                        default:;
                    endcase 
                default:;
            endcase
        end
        `INST_TYPE_IW:begin alu_src_sel = `ALU_SRC_IMM;
            case (funct3)
                `INST_ADDI:alu_op = `ALU_ADDW; //addiw
                `INST_SLLI:alu_op = `ALU_SLLW; 
                `INST_SRLI_SRAI: 
                    case(funct7)
                        `FUNCT7_INST_A:alu_op = `ALU_SRLW;
                        `FUNCT7_INST_B:alu_op = `ALU_SRAW;
                        default:;
                    endcase 
                default:;   
            endcase
        end
        `INST_CSR:
            case (funct3)
                `INST_CSRRW:  alu_op = `ALU_CSRRW;  
                `INST_CSRRS:  alu_op = `ALU_CSRRS;
                `INST_CSRRC:  alu_op = `ALU_CSRRC;
                `INST_CSRRWI: alu_op = `ALU_CSRRWI;
                `INST_CSRRSI: alu_op = `ALU_CSRRSI;
                `INST_CSRRCI: alu_op = `ALU_CSRRCI;
                default:;
            endcase 
        default:;
    endcase 
end

//=============4.BRANCH JUMP INFO================
  always@(*)begin
    branch      = 1'b0;
    jump        = 1'b0;
    jalr        = 1'b0;
    case(opcode)    
      `INST_TYPE_B: branch = 1;
      `INST_JAL:        jump  = 1'b1;                                     
      `INST_JALR: begin jump  = 1'b1; jalr = 1'b1; end
      default:;
    endcase
  end

//============5.LOAD STORE INFO==================
  always@(*)begin
    lsu_opt = `LSU_NOP;
    lsu_lden = 0;
    lsu_sten = 0;
    case(opcode)    
      `INST_TYPE_IL:begin lsu_opt = {funct3,1'b0}; lsu_lden = 1; end//0 represent load
      `INST_TYPE_S: begin lsu_opt = {funct3,1'b1}; lsu_sten = 1; end //1 represent store
      default:;
    endcase
  end

  
endmodule
