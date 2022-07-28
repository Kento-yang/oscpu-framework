`include "vsrc/rvseed_defines.sv"
// 除法模块
// 试商法实现32位整数除法
// 每次除法运算至少需要33个时钟周期才能完成
module div_32bit(

    input wire clk,
    input wire rst_n,

    // from ex
    input wire[31:0] dividend,      // 被除数
    input wire[31:0] divisor,       // 除数
    //input logic div_valid,
    input wire  start_i,                  // 开始信号，运算期间这个信号需要一直保持有效
    input wire[`ALU_OP_WIDTH-1:0] alu_op,                // 具体是哪一条指令
    //input wire[`RegAddrBus] reg_waddr_i, // 运算结束后需要写的寄存器

    // to ex
 
    output reg[31:0] quotient,       //商
    output reg[31:0] remainder,      //余数
    output reg busy_o,                  // 正在运算信号
    //output reg[`RegAddrBus] reg_waddr_o  // 运算结束后需要写的寄存器

    //handshake
    //input div_valid_pre_i,
    output logic div_ready_o_pre,

    output logic div_valid_o_next,// 运算结束信号
    input div_ready_next_i
);

    // 状态定义
    localparam STATE_IDLE  = 4'b0001;
    localparam STATE_CALC  = 4'b0010;
    localparam STATE_END   = 4'b0100;

    reg [31:0] dividend_r;
    reg [31:0] divisor_r;
    reg [`ALU_OP_WIDTH-1:0] alu_op_r;
    reg [3:0] state,next_state;
    reg [31:0] count;
    reg [31:0] div_result;
    reg [31:0] div_remain;
    reg [31:0] minuend;
    reg invert_result;

    wire op_div = (alu_op_r == `ALU_DIV);
    wire op_divu = (alu_op_r == `ALU_DIVU);
    wire op_divw = (alu_op_r == `ALU_DIVW);
    wire op_divuw = (alu_op_r == `ALU_DIVUW);
    wire op_div_inst = op_div || op_divu || op_divw || op_divuw;

    wire op_rem = (alu_op_r == `ALU_REM);
    wire op_remu = (alu_op_r == `ALU_REMU);
    wire op_remw = (alu_op_r ==`ALU_REMW);
    wire op_remuw = (alu_op_r ==`ALU_REMUW);
    wire op_rem_inst = op_rem || op_remu || op_remw || op_remuw;

    wire    [31:0] dividend_invert = (-dividend_r);
    wire    [31:0] divisor_invert = (-divisor_r);

    wire     minuend_ge_divisor = minuend >= divisor_r;//被减数大于等于除数
    wire    [31:0] minuend_sub_res = minuend - divisor_r;
    wire    [31:0] div_result_tmp = minuend_ge_divisor ? ({div_result[30:0], 1'b1}): ({div_result[30:0], 1'b0});//更新最高位，依次左移。
    wire    [31:0] minuend_tmp = minuend_ge_divisor ? {1'b0,minuend_sub_res[30:0]}: {1'b0,minuend[30:0]};//被除数更新为减法结果。

    logic div_valid_pre_i;

    logic [31:0] quotient_r,remainder_r;
// ----状态机实现----
    //1.状态切换
    always@(posedge clk or negedge rst_n)
        if(!rst_n)
            state <= STATE_IDLE;
        else
            state <= next_state;

    //2.state skip logic .comb
    always@(*)begin
        case(state)
            STATE_IDLE: begin
                    if (start_i == 1'b1)                        
                        next_state = STATE_CALC;
                    else
                        next_state = STATE_IDLE;        
                end
            STATE_CALC: begin
                    if (start_i == 1'b1 && (|count)) 
                        next_state = STATE_CALC;      
                    else if(start_i == 1'b1 && (|count == 0))
                        next_state = STATE_END;    
                    else
                        next_state = STATE_IDLE;       
                end
            STATE_END: begin
                    if (start_i == 1'b1 && div_ready_next_i && div_valid_o_next) //与后级握手成功且start还在
                        next_state = STATE_IDLE;//状态跳变
                    else if(start_i == 1'b1)
                        next_state = STATE_END;
                    else
                        next_state = STATE_IDLE;//状态跳变                   
                end
            default:next_state = STATE_IDLE;
        endcase
    end

    //3.output
    always @ (posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            div_valid_o_next <= 1'b0;
            quotient_r <= 32'h0;
            remainder_r<= 32'h0;
            div_result <= 32'h0;
            div_remain <= 32'h0;
            alu_op_r <= `ALU_OP_WIDTH'h0;
            dividend_r <= 32'h0;
            divisor_r <= 32'h0;
            minuend <= 32'h0;
            invert_result <= 1'b0;
            busy_o <= 1'b0;
            count <= 32'h0;
        end 
        else begin
            case (state)
                STATE_IDLE: begin
                    // 除数不为0
                    if (start_i == 1'b1) begin
                        alu_op_r <= alu_op;
                        dividend_r <= dividend;
                        divisor_r <= divisor;
                        div_result <= 32'h0;
                        div_remain <= 32'h0;
                        busy_o <= 1'b1;
                        count <= 32'h40000000;
                        div_valid_o_next <= 1'b0;
                        if (op_div | op_rem | op_divw | op_remw) begin // DIV和REM这两条指令是有符号数运算指令
                            // 被除数求补码  signed
                            if (dividend_r[31] == 1'b1) begin
                                dividend_r <= dividend_invert;
                                minuend <= {31'b0, dividend_invert[31]};
                            end 
                            else 
                                minuend <= {31'b0, dividend_r[31]};
                                
                            // 除数求补码
                            if (divisor_r[31] == 1'b1) begin
                                divisor_r <= divisor_invert;
                            end
                        end 
                        else begin
                            minuend <= {31'b0,dividend_r[31]};
                        end
                        // 运算结束后是否要对结果取补码
                        if ((op_div_inst && (dividend_r[31] ^ divisor_r[31] == 1'b1))
                            || (op_rem_inst && (dividend_r[31] == 1'b1))) 
                            invert_result <= 1'b1;      
                        else 
                            invert_result <= 1'b0;
                            
                    end 
                    // 除数为0
                    /*else if(start_i == 1'b1 && dividend ==32'h0 )begin
                            quotient_r <= 64'hffffffffffffffff;
                            remainder_r <= dividend_r;
                            div_valid_o_next <= 1'b0;
                            busy_o <= 1'b0;      
                            count <= 64'h0;    
                    end*/
                    else begin
                        alu_op_r <= `ALU_OP_WIDTH'h0;
                        dividend_r <= 32'h0;
                        divisor_r <= 32'h0;
                        div_valid_o_next <= 1'b0;
                        quotient_r <= 32'h0;
                        remainder_r<= 32'h0;
                        busy_o <= 1'b0;
                    end
                end
                STATE_CALC: begin
                    if (start_i == 1'b1) begin
                        dividend_r <= {dividend_r[30:0], 1'b0};
                        div_result <= div_result_tmp;
                        div_valid_o_next <= 1'b0;
                        count <= {1'b0, count[31:1]};
                        if (|count) begin
                            minuend <= {minuend_tmp[30:0], dividend_r[30]};
                        end 
                        else begin
                            div_valid_o_next <= 1'b1;
                            if (minuend_ge_divisor) begin
                                div_remain <= minuend_sub_res;
                            end else begin
                                div_remain <= minuend;
                            end
                        end
                    end else begin
                        quotient_r <= 32'h0;
                        remainder_r<= 32'h0;
                        div_valid_o_next <= 1'b0;
                        busy_o <= 1'b0;
                    end
                end
                STATE_END: begin
                    if (start_i == 1'b1) begin
                        busy_o <= 1'b0;
                        if (invert_result) begin
                            quotient_r <= (-div_result);
                            remainder_r<= (-div_remain);
                        end 
                        else begin
                            quotient_r <= div_result;
                            remainder_r<= div_remain;
                        end
                        if(div_ready_next_i && div_valid_o_next)
                            div_valid_o_next <= 1'b0;
                        else
                            div_valid_o_next <= 1'b1;
                    end
                    else begin
                        quotient_r <= 32'h0;
                        remainder_r<= 32'h0;
                        div_valid_o_next <= 1'b0;
                        busy_o <= 1'b0;
                    end
                end
                default:;
            endcase
        end
    end

    assign quotient = (invert_result)? (-div_result) : div_result;
    assign remainder = (invert_result)? (-div_remain) : div_remain;

    assign div_valid_pre_i = (|count == 0) && (start_i);
    assign div_ready_o_pre = (|count == 0) && (!div_valid_o_next);

endmodule

/*
"div.v is licensed under Apache-2.0 (http://www.apache.org/licenses/LICENSE-2.0)
   by Blue Liang, liangkangnan@163.com.
*/