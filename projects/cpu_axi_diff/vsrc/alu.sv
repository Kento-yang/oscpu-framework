`include "rvseed_defines.sv"

module alu(
    input                                 clk,
    input                                 rst_n,
    input        [`ALU_OP_WIDTH-1:0]  alu_op,   // alu opcode
    input        [`DATA_WIDTH-1:0]    alu_src1, // alu source 1
    input        [`DATA_WIDTH-1:0]    alu_src2, // alu source 2
    //input                                start, //div_start

    output logic [`DATA_WIDTH-1:0]    alu_res,   // alu result

    output logic                        zero,   // alu result is zero    
//CSR
    input    [`CSR_IMM_WIDTH -1:0]       csr_zimm,     // 写CSR寄存器地址
    input    [`DATA_WIDTH - 1 : 0]       csr_rdata,         // CSR寄存器数据
    output reg   [`DATA_WIDTH - 1 : 0]   csr_wdata,         // CSR寄存器数据

    //div handshake
    output logic                       div_ready_o_pre,
    input                              div_ready_next_i,
    output logic                       alu_valid_o_next//alu resuly valid
    
        // div开始信号，运算期间这个信号需要一直保持有效
);

    logic                        sububit; // use for sltu,bltu,bgeu
      // ！！硬件中不区分有符号和无符号，全部按照补码进行运算！！
      // 所以 src1 - src2 得到是补码！ 如果src1和src2是有符号数，通过输出最高位就可以判断正负！
      // 如果src1和src2是无符号数，那么就在最高位补0，拓展为有符号数再减法，通过最高位判断正负！
    logic  [ 65 :0] A;
    logic  [ 65 :0] B;
    logic  [131 :0] P;//discard high bit


always_comb begin
    alu_res = 64'b0; zero = 0; dividend = 64'h0; divisor = 64'h0; A = 66'h0; B = 66'h0; sububit = 0; csr_wdata = 64'h0;
    case (alu_op)
        `ALU_AND:   alu_res = alu_src1 &  alu_src2;
        `ALU_OR:    alu_res = alu_src1 |  alu_src2;
        `ALU_XOR:   alu_res = alu_src1 ^  alu_src2;
        `ALU_ADD:   alu_res = alu_src1 +  alu_src2;
        `ALU_ADDW:begin alu_res[31:0] = alu_src1[31:0] + alu_src2[31:0]; alu_res = {{32 {alu_res[31]}}, alu_res[31:0]}; end   
        `ALU_SUB: begin alu_res = alu_src1 -  alu_src2; zero = (alu_res == `DATA_WIDTH'b0) ? 1'b1 : 1'b0; end
        `ALU_SUBW:begin alu_res[31:0] = alu_src1[31:0] - alu_src2[31:0]; alu_res = {{ 32 {alu_res[31]} }, alu_res[31:0]};zero = (alu_res == `DATA_WIDTH'b0) ? 1'b1 : 1'b0; end   
        `ALU_SLL: alu_res = alu_src1 <<  alu_src2[5:0];
        `ALU_SRL: alu_res = alu_src1 >>  alu_src2[5:0]; 
        `ALU_SRA: alu_res = { { {64 {alu_src1[63]} } ,alu_src1} >>  alu_src2[5:0] } [63:0];

        `ALU_SLLW:begin alu_res[31:0] = alu_src1[31:0] <<  alu_src2[4:0]; alu_res = {{ 32 {alu_res[31]} }, alu_res[31:0]}; end
        `ALU_SRLW:begin alu_res[31:0] = alu_src1[31:0] >>  alu_src2[4:0]; alu_res = {{ 32 {alu_res[31]} }, alu_res[31:0]}; end
        `ALU_SRAW:begin alu_res[31:0] = {{{ 32 {alu_src1[31]} }, alu_src1[31:0]} >>  alu_src2[4:0]}[31:0] ; alu_res = {{ 32 {alu_res[31]} }, alu_res[31:0]}; end
        
        `ALU_SLT:begin alu_res = alu_src1 - alu_src2; alu_res = {63'b0,alu_res[63]}; end
        `ALU_BLT:begin alu_res = alu_src1 - alu_src2; zero = ~alu_res[63]; end
        `ALU_BLTU:begin {sububit,alu_res} = {1'b0,alu_src1} - {1'b0,alu_src2};  alu_res = {63'b0, sububit}; zero = ~sububit; end// use for bltu,bgeu rs1<rs2
        `ALU_SUBU:begin {sububit,alu_res} = {1'b0,alu_src1} - {1'b0,alu_src2};  alu_res = {63'b0, sububit};end//rs1<rs2  use for sltu,
        `ALU_BEQ:zero = (alu_src1 == alu_src2) ? 0 : 1;
        `ALU_BGE:begin alu_res = alu_src1 - alu_src2; zero = alu_res[63]; end
        `ALU_BGEU:begin {sububit,alu_res} = {1'b0,alu_src1} - {1'b0,alu_src2};  alu_res = {63'b0, sububit}; zero = sububit; end // use for sltu,bltu,bgeu//rs1<rs2
    //MUL
        `ALU_MUL:  begin A = { {2{alu_src1[`DATA_WIDTH-1]}}, alu_src1}; B = { {2{alu_src2[`DATA_WIDTH-1]}}, alu_src2}; alu_res = P[`DATA_WIDTH-1:0];end  //alu_res = alu_src1 * alu_src2;
        `ALU_MULH: begin A = { {2{alu_src1[`DATA_WIDTH-1]}}, alu_src1}; B = { {2{alu_src2[`DATA_WIDTH-1]}}, alu_src2}; alu_res = P[ 2*`DATA_WIDTH-1:`DATA_WIDTH];end  //alu_res = alu_src1 * alu_src2 >> 64;
        `ALU_MULSU:begin A = { 2'b00, alu_src1}; B = { {2{alu_src2[`DATA_WIDTH-1]}}, alu_src2}; alu_res = {P >> 64}[63:0];end //alu_res = {{1'b0, alu_src1} * alu_src2 >> 64}[63:0];
        `ALU_MULHU:begin A = { 2'b00, alu_src1}; B = { 2'b00, alu_src2}; alu_res = {P >> 64}[63:0];end //alu_res = {{1'b0, alu_src1} * {1'b0, alu_src2} >> 64}[63:0]; 
        `ALU_MULW: begin A[31:0] = alu_src1[31:0]; B[31:0] = alu_src2[31:0]; alu_res[63:0] = {{32{P[31]}}, P[31:0]}; end//begin  alu_res[31:0] = {alu_src1[31:0] * alu_src2[31:0]}[31:0]; alu_res = {{32{alu_res[31]}}, alu_res[31:0]}; end
    //DIV
        `ALU_DIV,`ALU_DIVU:begin 
                        if(alu_src1 == `DATA_WIDTH'h0 )
                            alu_res = `DATA_WIDTH'h0;
                        else begin
                            dividend = alu_src1; divisor = alu_src2; alu_res = quotient;
                        end
                    end    
        //div:alu_res = alu_src1 / alu_src2;
        //divu:alu_res = {{1'b0, alu_src1} / {1'b0, alu_src2}}[63:0];
        `ALU_REM,`ALU_REMU:begin 
                        if(alu_src1 == `DATA_WIDTH'h0 )
                            alu_res = `DATA_WIDTH'h0;
                        else begin
                            dividend = alu_src1; divisor = alu_src2; alu_res = remainder;
                        end
                    end 
        //REM:alu_res = alu_src1 % alu_src2;
        //REMU:alu_res = {{1'b0, alu_src1} % {1'b0, alu_src2}}[63:0];
        `ALU_DIVW,`ALU_DIVUW:begin 
                        if(alu_src1 == `DATA_WIDTH'h0 )
                            alu_res = `DATA_WIDTH'h0;
                        else begin
                            dividend[31:0] = alu_src1[31:0]; divisor[31:0] = alu_src2[31:0]; alu_res = {{32{quotient[31]}}, quotient[31:0]};
                        end 
                    end
        //ALU_DIVW:begin  alu_res[31:0] = {alu_src1[31:0] / alu_src2[31:0]};       alu_res = {{32{alu_res[31]}}, alu_res[31:0]}; end
        //ALU_DIVUW:begin alu_res[31:0] = {{1'b0,alu_src1[31:0]}/{1'b0,alu_src2[31:0]}}[31:0];  alu_res = {{32{alu_res[31]}}, alu_res[31:0]};  end
        `ALU_REMW,`ALU_REMUW:begin 
                        if(alu_src1 == `DATA_WIDTH'h0 )
                            alu_res = `DATA_WIDTH'h0;
                        else begin
                            dividend[31:0] = alu_src1[31:0]; divisor[31:0] = alu_src2[31:0]; alu_res = {{32{remainder[31]}}, remainder[31:0]};
                        end 
                    end  
        //ALU_REMW:begin alu_res[31:0] = {alu_src1[31:0] % alu_src2[31:0]};      alu_res = {{32{alu_res[31]}}, alu_res[31:0]}; end
        //ALU_REMUW:begin alu_res[31:0] = {{1'b0,alu_src1[31:0]}%{1'b0,alu_src2[31:0]}}[31:0]; alu_res = {{32{alu_res[31]}}, alu_res[31:0]}; end
    //CSR
        `ALU_CSRRW :begin csr_wdata = alu_src1;                         alu_res = csr_rdata;end
        `ALU_CSRRS :begin csr_wdata = csr_rdata | alu_src1 ;            alu_res = csr_rdata; end
        `ALU_CSRRC :begin csr_wdata = csr_rdata & (~alu_src1);          alu_res = csr_rdata; end
        `ALU_CSRRWI:begin csr_wdata = {59'h0, csr_zimm};                alu_res = csr_rdata; end
        `ALU_CSRRSI:begin csr_wdata = {59'h0, csr_zimm} | csr_rdata;    alu_res = csr_rdata; end
        `ALU_CSRRCI:begin csr_wdata = (~{59'h0, csr_zimm}) & csr_rdata; alu_res = csr_rdata; end
        default: begin alu_res = 64'b0; zero = 0; dividend = 64'h0; divisor = 64'h0; A = 66'h0; B = 66'h0; sububit = 0; csr_wdata = 64'h0;end
    endcase
end
//for valid
logic div_valid_o_next;

always_comb begin
    alu_valid_o_next = 1'b1;
    case (alu_op)
    //MUL
        `ALU_MUL:  alu_valid_o_next = 1'b1;
        `ALU_MULH: alu_valid_o_next = 1'b1;
        `ALU_MULSU:alu_valid_o_next = 1'b1;
        `ALU_MULHU:alu_valid_o_next = 1'b1;
        `ALU_MULW: alu_valid_o_next = 1'b1;
    //DIV
        `ALU_DIV:  alu_valid_o_next = div_valid_o_next || alu_src1 == `DATA_WIDTH'h0 ;//div完成，或者当前是div但是除数=0。
        `ALU_DIVU: alu_valid_o_next = div_valid_o_next || alu_src1 == `DATA_WIDTH'h0 ;
        `ALU_REM:  alu_valid_o_next = div_valid_o_next || alu_src1 == `DATA_WIDTH'h0 ;
        `ALU_REMU: alu_valid_o_next = div_valid_o_next || alu_src1 == `DATA_WIDTH'h0 ;
        `ALU_DIVW: alu_valid_o_next = div_valid_o_next || alu_src1 == `DATA_WIDTH'h0 ;
        `ALU_DIVUW:alu_valid_o_next = div_valid_o_next || alu_src1 == `DATA_WIDTH'h0 ;
        `ALU_REMW: alu_valid_o_next = div_valid_o_next || alu_src1 == `DATA_WIDTH'h0 ;
        `ALU_REMUW:alu_valid_o_next = div_valid_o_next || alu_src1 == `DATA_WIDTH'h0 ;
        default:   alu_valid_o_next = 1'b1; 
    endcase 
end

//mult for HIGH PERFORMANCE MUL INST
    booth_wallace_mult_top#(
        .WIDTH ( 66 )
    )u_booth_wallace_mult_top(
        .A ( A ),
        .B ( B ),
        .P ( P )
    );
//div

    logic [`DATA_WIDTH-1:0] dividend,dividend_r;      // 被除数
    logic [`DATA_WIDTH-1:0] divisor,divisor_r;       // 除数
    logic start;
    // to ex
    logic [`DATA_WIDTH-1:0] quotient,remainder;        // 除法结果，高32位是余数，低32位是商
    logic busy;
    logic alu_div_rem_op;

    assign alu_div_rem_op =   (alu_op ==`ALU_DIV)  || (alu_op ==`ALU_DIVU)  || (alu_op ==`ALU_REM)  || (alu_op ==`ALU_REMU) ||  
                              (alu_op ==`ALU_DIVW) || (alu_op ==`ALU_DIVUW) || (alu_op ==`ALU_REMW) || (alu_op ==`ALU_REMUW);
    //alu_div_rem_op <= 68'h1 0000 0000 0000 0000;
    //检测到除法指令，立即暂停流水线运行。
    logic [6:0]  cnt;

    always@(posedge clk or negedge rst_n) begin
        if(!rst_n)
            start <= 0;
            //start <= 0;
        else if(alu_div_rem_op == 1 && !div_valid_o_next && dividend != `DATA_WIDTH'h0)begin
            start <= 1;
            dividend_r <= dividend;
            divisor_r  <= divisor;
        end
        else
            start <= 0; 
    end


    //assign div_valid_o_next = ~start;
    //logic divw;//1:32bit 0:64bit
    div_64bit u_div_64bit(
        .clk      ( clk      ),
        .rst_n    ( rst_n    ),
        .dividend ( dividend_r ),
        .divisor  ( divisor_r  ),
        .start_i  ( start    ),
        .alu_op   ( alu_op   ),
        .quotient ( quotient ),
        .remainder(remainder),
        .busy_o   ( busy   ),

        .div_ready_o_pre (  div_ready_o_pre ),
        .div_valid_o_next(  div_valid_o_next),
        .div_ready_next_i( div_ready_next_i)
    );


endmodule
 