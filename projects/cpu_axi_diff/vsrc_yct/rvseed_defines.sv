//from defines.v
`timescale 1ns / 1ps

`define ZERO_WORD  64'h00000000_00000000
`define PC_START   64'h00000000_80000000  
`define REG_BUS    63 : 0     
`define INST_ADD   8'h11

`define AXI_ADDR_WIDTH      64
`define AXI_DATA_WIDTH      64
`define AXI_ID_WIDTH        4
`define AXI_USER_WIDTH      1

`define SIZE_B              2'b00
`define SIZE_H              2'b01
`define SIZE_W              2'b10
`define SIZE_D              2'b11

`define REQ_READ            1'b0
`define REQ_WRITE           1'b1

`define RISCV_PRIV_MODE_U   0
`define RISCV_PRIV_MODE_S   1
`define RISCV_PRIV_MODE_M   3


//rvseed_defines
// simulation clock period
`define SIM_PERIOD 20 // 20ns -> 50MHz 

// processor numbers
`define INST_WIDTH 32 // rv64 but isa 32bit
`define DATA_WIDTH 64 // data 64bit
`define PC_WIDTH    64 //0x0000`0000`8000`0000~0x0000_0000_87ff_ffff

// instruction memory
`define INST_MEM_ADDR_DEPTH 1024
`define INST_MEM_ADDR_WIDTH 10 // 2^10 = 1024

// register 
`define REG_NUM 32 //32 reg
`define REG_ADDR_WIDTH 5 // 2^5 = 32
// csr register
`define CSR_ADDR_WIDTH 12 // csr addr width
`define CSR_IMM_WIDTH 5 
//i-type-shamt
`define ITYPE_SHAMT 6

// immediate generate
`define INST_I_IMM_WIDTH 12
`define INST_S_IMM_WIDTH 12
`define INST_B_IMM_WIDTH 13
`define INST_U_IMM_WIDTH 32
`define INST_J_IMM_WIDTH 21

// instruction bits select
`define FUNCT3_BASE 12
`define FUNCT7_BASE 25
`define RD_BASE     7
`define RS1_BASE    15
`define RS2_BASE    20

// opcode [6:0]
`define OPCODE_WIDTH 7
`define INST_TYPE_R  `OPCODE_WIDTH'b0110011 // add/sub/xor/or/and/sll/srl/sra/slt/sltu
`define INST_TYPE_RW `OPCODE_WIDTH'b0111011 // RV64M
`define INST_TYPE_I  `OPCODE_WIDTH'b0010011 // addi/xori/ori/andi/slli/srli/srai/slti/sltiu
`define INST_TYPE_IL `OPCODE_WIDTH'b0000011 // lb/lh/lw/lbu/lhu  (RV64I)ld/lwu
`define INST_TYPE_IW `OPCODE_WIDTH'b0011011  //addiw/slliw/srliw/sraiw
`define INST_TYPE_S  `OPCODE_WIDTH'b0100011 // sb/sh/sw (RV64I)sd
`define INST_TYPE_B  `OPCODE_WIDTH'b1100011 // beq/bne/blt/bge/bltu/bgeu
`define INST_JAL     `OPCODE_WIDTH'b1101111 // jal
`define INST_JALR    `OPCODE_WIDTH'b1100111 // jalr
`define INST_LUI     `OPCODE_WIDTH'b0110111 // lui
`define INST_AUIPC   `OPCODE_WIDTH'b0010111 // auipc
`define INST_CSR     `OPCODE_WIDTH'b1110011 // ecall/ebreak

// CSR reg addr
`define INST_MRET   32'h30200073
`define ECALL  32'h73
`define EBREAK 32'h00100073

`define ADDR_CSR_CYCLE   12'hc00
`define ADDR_CSR_CYCLEH  12'hc80
`define ADDR_CSR_MSTATUS 12'h300
`define ADDR_CSR_MIE     12'h304
`define ADDR_CSR_MTVEC   12'h305
`define ADDR_CSR_MEPC    12'h341
`define ADDR_CSR_MCAUSE  12'h342

//`define CSR_MSCRATCH 12'h340
// funct3
// R-type
`define FUNCT3_WIDTH 3
`define INST_ADD_SUB_MUL   `FUNCT3_WIDTH'h0 
`define INST_XOR       `FUNCT3_WIDTH'h4
`define INST_OR        `FUNCT3_WIDTH'h6
`define INST_AND       `FUNCT3_WIDTH'h7
`define INST_SLL       `FUNCT3_WIDTH'h1
`define INST_SRL_SRA   `FUNCT3_WIDTH'h5
`define INST_SLT       `FUNCT3_WIDTH'h2
`define INST_SLTU      `FUNCT3_WIDTH'h3
// I-type 
`define INST_ADDI      `FUNCT3_WIDTH'h0
`define INST_XORI      `FUNCT3_WIDTH'h4
`define INST_ORI       `FUNCT3_WIDTH'h6
`define INST_ANDI      `FUNCT3_WIDTH'h7
`define INST_SLLI      `FUNCT3_WIDTH'h1
`define INST_SRLI_SRAI `FUNCT3_WIDTH'h5 
`define INST_SLTI      `FUNCT3_WIDTH'h2
`define INST_SLTIU     `FUNCT3_WIDTH'h3
// I-type load
`define INST_LB        `FUNCT3_WIDTH'h0
`define INST_LH        `FUNCT3_WIDTH'h1
`define INST_LW        `FUNCT3_WIDTH'h2
`define INST_LBU       `FUNCT3_WIDTH'h4
`define INST_LHU       `FUNCT3_WIDTH'h5
// S-type
`define INST_SB        `FUNCT3_WIDTH'h0
`define INST_SH        `FUNCT3_WIDTH'h1
`define INST_SW        `FUNCT3_WIDTH'h2
// B-type
`define INST_BEQ       `FUNCT3_WIDTH'h0
`define INST_BNE       `FUNCT3_WIDTH'h1
`define INST_BLT       `FUNCT3_WIDTH'h4
`define INST_BGE       `FUNCT3_WIDTH'h5
`define INST_BLTU      `FUNCT3_WIDTH'h6
`define INST_BGEU      `FUNCT3_WIDTH'h7
// I-type environment
`define INST_ECALL     `FUNCT3_WIDTH'h0
`define INST_EBREAK    `FUNCT3_WIDTH'h0
//I-type RC32/64 Zicsr
`define INST_CSRRW     `FUNCT3_WIDTH'h1
`define INST_CSRRS     `FUNCT3_WIDTH'h2
`define INST_CSRRC     `FUNCT3_WIDTH'h3
`define INST_CSRRWI    `FUNCT3_WIDTH'h5
`define INST_CSRRSI    `FUNCT3_WIDTH'h6
`define INST_CSRRCI    `FUNCT3_WIDTH'h7
//R-type RV32M
`define INST_MUL       `FUNCT3_WIDTH'h0 
`define INST_MULH      `FUNCT3_WIDTH'h1
`define INST_MULSU     `FUNCT3_WIDTH'h2
`define INST_MULU      `FUNCT3_WIDTH'h3
`define INST_DIV       `FUNCT3_WIDTH'h4
`define INST_DIVU      `FUNCT3_WIDTH'h5
`define INST_REM       `FUNCT3_WIDTH'h6
`define INST_REMU      `FUNCT3_WIDTH'h7

//R-TYPE RV64M
`define INST_DIVW      `FUNCT3_WIDTH'h4
`define INST_DIVUW      `FUNCT3_WIDTH'h5
`define INST_REMW       `FUNCT3_WIDTH'h6
`define INST_REMUW      `FUNCT3_WIDTH'h7

`define INST_SRLW_SRAW `FUNCT3_WIDTH'h5

`define EBREAK_INST     32'h00100073

// funct7
`define FUNCT7_WIDTH 7
`define FUNCT7_INST_A  `FUNCT7_WIDTH'h00
`define FUNCT7_INST_B  `FUNCT7_WIDTH'h20
`define FUNCT7_INST_RV_M  `FUNCT7_WIDTH'h01


// ALU opcode
`define ALU_OP_WIDTH 6
`define ALU_AND  `ALU_OP_WIDTH'b000000
`define ALU_OR   `ALU_OP_WIDTH'b000001
`define ALU_XOR  `ALU_OP_WIDTH'b000010
`define ALU_ADD  `ALU_OP_WIDTH'b000011
`define ALU_SUB  `ALU_OP_WIDTH'b000100
`define ALU_SLL  `ALU_OP_WIDTH'b000101 // shift left logical
`define ALU_SRL  `ALU_OP_WIDTH'b000110 // shift right logical
`define ALU_SRA  `ALU_OP_WIDTH'b000111 // shift right arith 
`define ALU_SLT  `ALU_OP_WIDTH'b001000 // set less than  
`define ALU_SLTU `ALU_OP_WIDTH'b001001 // set less than (unsigned) 
`define ALU_BLT  `ALU_OP_WIDTH'b001010 // branch less than
`define ALU_BLTU `ALU_OP_WIDTH'b001011 // branch less than (unsigned)
`define ALU_BGE  `ALU_OP_WIDTH'b010100
`define ALU_BGEU `ALU_OP_WIDTH'b010101
`define ALU_JAL  `ALU_OP_WIDTH'b001100  
`define ALU_JALR `ALU_OP_WIDTH'b001101

`define ALU_ADDW `ALU_OP_WIDTH'b001110
`define ALU_SUBW `ALU_OP_WIDTH'b001111

`define ALU_SLLW `ALU_OP_WIDTH'b010000
`define ALU_SRLW `ALU_OP_WIDTH'b010001
`define ALU_SRAW `ALU_OP_WIDTH'b010010

`define ALU_BEQ  `ALU_OP_WIDTH'b010011
`define ALU_SUBU `ALU_OP_WIDTH'b010110
`define ALU_MUL  `ALU_OP_WIDTH'b010111
`define ALU_MULU  `ALU_OP_WIDTH'b100100
`define ALU_MULH `ALU_OP_WIDTH'b011000
`define ALU_MULSU `ALU_OP_WIDTH'b011001
`define ALU_MULHU `ALU_OP_WIDTH'b011010
`define ALU_DIV  `ALU_OP_WIDTH'b011011
`define ALU_DIVU `ALU_OP_WIDTH'b011100
`define ALU_REM  `ALU_OP_WIDTH'b011101
`define ALU_REMU `ALU_OP_WIDTH'b011110
`define ALU_MULW `ALU_OP_WIDTH'b011111
`define ALU_DIVW `ALU_OP_WIDTH'b100000
`define ALU_DIVUW `ALU_OP_WIDTH'b100001
`define ALU_REMW `ALU_OP_WIDTH'b100010
`define ALU_REMUW `ALU_OP_WIDTH'b100011


`define ALU_SLLI `ALU_OP_WIDTH'b100100
`define ALU_SRLI `ALU_OP_WIDTH'b100101
`define ALU_SRAI `ALU_OP_WIDTH'b100110
//csr aluop
`define ALU_CSRRW `ALU_OP_WIDTH'b100111
`define ALU_CSRRS `ALU_OP_WIDTH'b101000
`define ALU_CSRRC `ALU_OP_WIDTH'b101001
`define ALU_CSRRWI `ALU_OP_WIDTH'b101010
`define ALU_CSRRSI `ALU_OP_WIDTH'b101011
`define ALU_CSRRCI `ALU_OP_WIDTH'b101100



//`define ALU_LUI `ALU_OP_WIDTH'b100111
// ALU select soure
`define ALU_SRC_WIDTH 2
`define ALU_SRC_REG     `ALU_SRC_WIDTH'b00 // src1 = reg1, src2 = reg2
`define ALU_SRC_IMM     `ALU_SRC_WIDTH'b01 // src1 = reg1, src2 = imm
`define ALU_SRC_FOUR_PC `ALU_SRC_WIDTH'b10 // src1 = 4,    src2 = pc
`define ALU_SRC_IMM_PC  `ALU_SRC_WIDTH'b11 // src1 = imm,  src2 = pc

// IMM GEN opcode
`define IMM_GEN_OP_WIDTH 3
`define IMM_GEN_I `IMM_GEN_OP_WIDTH'b000 
`define IMM_GEN_S `IMM_GEN_OP_WIDTH'b001
`define IMM_GEN_B `IMM_GEN_OP_WIDTH'b010
`define IMM_GEN_J `IMM_GEN_OP_WIDTH'b011
`define IMM_GEN_U `IMM_GEN_OP_WIDTH'b100

//Load Store opcode
//{funct3,ld(0)/st(1)}
`define LSU_OPT_WIDTH   4
`define LSU_LB   `LSU_OPT_WIDTH'b000_0    // 0x0 for FUNC3_LB_SB, 0 for load
`define LSU_LH   `LSU_OPT_WIDTH'b001_0    // 0x1 for FUNC3_LH_SH, 0 for load
`define LSU_LW   `LSU_OPT_WIDTH'b010_0    // 0x2 for FUNC3_LW_SW, 0 for load
`define LSU_LD   `LSU_OPT_WIDTH'b011_0    // RV64I/0x3 for FUNC3_LD_SD, 0 for load
`define LSU_LBU  `LSU_OPT_WIDTH'b100_0    // 0x4 for FUNC3_LBU,   0 for load
`define LSU_LHU  `LSU_OPT_WIDTH'b101_0    // 0x5 for FUNC3_LHU,   0 for load
`define LSU_LWU  `LSU_OPT_WIDTH'b110_0    // RV64I/0x6 for FUNC3_LWU,   0 for load
`define LSU_SB   `LSU_OPT_WIDTH'b000_1    // 0x0 for FUNC3_LB_SB, 1 for store
`define LSU_SH   `LSU_OPT_WIDTH'b001_1    // 0x1 for FUNC3_LH_SH, 1 for store
`define LSU_SW   `LSU_OPT_WIDTH'b010_1    // 0x2 for FUNC3_LW_SW, 1 for store
`define LSU_SD   `LSU_OPT_WIDTH'b011_1    // RV64I/0x3 for FUNC3_LD_SD, 1 for store
`define LSU_NOP  `LSU_OPT_WIDTH'b111_1    //1111 for nop!! "lowest bit = 0" <=> "this is an load ins"


// clint define:
`define CLINT_BASE_ADDR `DATA_WIDTH'h2000000                // 0x0200_0000~0x0200_ffff
`define CLINT_END_ADDR  `DATA_WIDTH'h200ffff                // 0x0200_0000~0x0200_ffff
`define MSIP_ADDR       `CLINT_BASE_ADDR+`DATA_WIDTH'h0000  //software interrupt, no use
`define MTIMECMP_ADDR   `CLINT_BASE_ADDR+`DATA_WIDTH'h4000
`define MTIME_ADDR      `CLINT_BASE_ADDR+`DATA_WIDTH'hBFF8

// intr define:
`define IRQ_TIMER       `DATA_WIDTH'h80000000_00000007
`define IRQ_ECALL       `DATA_WIDTH'd11