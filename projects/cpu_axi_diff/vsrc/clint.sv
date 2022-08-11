`include "rvseed_defines.sv"

// core local interruptor module
// 核心中断管理、仲裁模块
/*
CLINT 模块：中断控制模块，负责配置中断/异常相关的CSR、产生中断跳转、读写CLINT
寄存器。CLINT 采集送入IDU 的pc 和指令，并且检查是否为异常指令、异常返回指令，如
果是则配置CSR 寄存器，然后产生中断（异常）信号到EXU 模块，由EXU 产生跳转信号给
IFU。对于中断，则需要判断送入的指令是否执行完成，需要统一等到该指令执行完后再产
生中断。
*/
/*
module clint(

    input wire clk,
    input wire rst_n,

    // from id
    input wire[`INST_WIDTH-1 :0] inst,  // 指令内容
    input wire inst_fetched,
    input wire[`PC_WIDTH-1:0]  curr_pc,       // 指令地址

    // from ex
    input wire jump_flag_i,
    input wire[`PC_WIDTH-1:0] jump_addr_i,
    input wire div_started_i,

    //from mem
    input wire mem_done,

    // from csr_reg
    input wire[`DATA_WIDTH-1:0] csr_mtvec,           // mtvec寄存器
    input wire[`DATA_WIDTH-1:0] csr_mepc,            // mepc寄存器
    input wire[`DATA_WIDTH-1:0] csr_mstatus,         // mstatus寄存器
    input wire[`DATA_WIDTH-1:0] csr_mip,             // mip寄存器
    input wire[`DATA_WIDTH-1:0] csr_mie,         // mie寄存器

    input wire global_int_en_i,              // 全局中断使能标志
    //from mem, timer reg 
    input wire ClintReg_wen,
    input wire ClintReg_ren,
    input wire [15:0] ClintReg_waddr_i,
    input wire [`DATA_WIDTH-1:0] ClintReg_wdata_i,
    input wire [15:0] ClintReg_raddr_i,

    //to mem
    output reg [63:0]ClintReg_rdata_o,
    // to ctrl
    output wire flush,                 // 流水线暂停标志

    // to csr_reg
    output reg csr_we_o,                         // 写CSR寄存器标志
    output reg[`CSR_ADDR_WIDTH-1:0] csr_waddr_o,         // 写CSR寄存器地址
    output reg[`DATA_WIDTH-1:0] csr_wdata_o,              // 写CSR寄存器数据

    // to ex
    output reg[`PC_WIDTH-1:0] int_pc_o,             // 中断入口地址
    output reg int_flag_o                  // 中断标志

);
    // 中断状态定义
    logic [3:0] int_state;
    localparam S_INT_IDLE            = 4'b0001;
    localparam S_INT_SYNC_ASSERT     = 4'b0010;
    localparam S_INT_ASYNC_ASSERT    = 4'b0100;
    localparam S_INT_MRET            = 4'b1000;

    // 写CSR寄存器状态定义
    logic [4:0] csr_state;
    localparam S_CSR_IDLE            = 5'b00001;
    localparam S_CSR_MSTATUS         = 5'b00010;
    localparam S_CSR_MEPC            = 5'b00100;
    localparam S_CSR_MSTATUS_MRET    = 5'b01000;
    localparam S_CSR_MCAUSE          = 5'b10000;

   
    
    reg[31:0] inst_addr;
    reg[31:0] cause;


    assign flush = ((int_state != S_INT_IDLE) | (csr_state != S_CSR_IDLE))? 1'b1: 1'b0;


    // 中断仲裁逻辑
    always @ (*) begin
        if (!rst_n) begin
            int_state = S_INT_IDLE;
        end else begin
            if (inst == `ECALL || inst == `EBREAK) begin
                // 如果执行阶段的指令为除法指令，则先不处理同步中断，等除法指令执行完再处理
                if (div_started_i == 1'b0) begin
                    int_state = S_INT_SYNC_ASSERT;
                end else begin
                    int_state = S_INT_IDLE;
                end
            end else if (lobal_int_en_i == 1'b1) begin//判断是否有中断信号产生，如果是则设置中断状态，表示有异步中断要处理。
                int_state = S_INT_ASYNC_ASSERT;
            end else if (inst == `INST_MRET) begin//判断中断返回
                int_state = S_INT_MRET;
            end else begin
                int_state = S_INT_IDLE;
            end
        end
    end

    // 写CSR寄存器状态切换
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            csr_state <= S_CSR_IDLE;
            cause <= 32'h0;
            inst_addr <= 32'h0;
        end else begin
            case (csr_state)
                S_CSR_IDLE: begin
                    // 同步中断
                    if (int_state == S_INT_SYNC_ASSERT) begin
                        csr_state <= S_CSR_MEPC;
                        // 在中断处理函数里会将中断返回地址加4
                        if (jump_flag_i == 1'b1) begin
                            inst_addr <= jump_addr_i - 4'h4;
                        end else begin
                            inst_addr <= curr_pc;
                        end
                        case (inst)//根据不同的指令类型设置不同的中断码，可以让软件中断服务程序知道中断发生原因。
                            `ECALL: begin
                                cause <= 32'd11;
                            end
                            `EBREAK: begin
                                cause <= 32'd3;
                            end
                            default: begin
                                cause <= 32'd10;
                            end
                        endcase
                    // 异步中断
                    end else if (int_state == S_INT_ASYNC_ASSERT) begin
                        // 定时器中断
                        cause <= 32'h80000004;
                        csr_state <= S_CSR_MEPC;
                        if (jump_flag_i == 1'b1) begin
                            inst_addr <= jump_addr_i;
                        // 异步中断可以中断除法指令的执行，中断处理完再重新执行除法指令
                        end else if (div_started_i == 1'b1) begin
                            inst_addr <= curr_pc - 4'h4;
                        end else begin
                            inst_addr <= curr_pc;
                        end
                    // 中断返回
                    end else if (int_state == S_INT_MRET) begin
                        csr_state <= S_CSR_MSTATUS_MRET;
                    end
                end
                //一个时钟切换一下CSR中断
                S_CSR_MEPC: begin
                    csr_state <= S_CSR_MSTATUS;
                end
                S_CSR_MSTATUS: begin
                    csr_state <= S_CSR_MCAUSE;
                end
                S_CSR_MCAUSE: begin
                    csr_state <= S_CSR_IDLE;
                end
                S_CSR_MSTATUS_MRET: begin
                    csr_state <= S_CSR_IDLE;
                end
                default: begin
                    csr_state <= S_CSR_IDLE;
                end
            endcase
        end
    end

    // 发出中断信号前，先写几个CSR寄存器
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            we_o <= 1'b0;
            waddr_o <= 32'h0;
            data_o <= 32'h0;
        end else begin
            case (csr_state)
                // 将mepc寄存器的值设为当前指令地址
                S_CSR_MEPC: begin
                    we_o <= 1'b1;
                    waddr_o <= {20'h0, `CSR_MEPC};
                    data_o <= inst_addr;
                end
                // 写中断产生的原因
                S_CSR_MCAUSE: begin
                    we_o <= 1'b1;
                    waddr_o <= {20'h0, `CSR_MCAUSE};
                    data_o <= cause;
                end
                // 关闭全局中断
                S_CSR_MSTATUS: begin
                    we_o <= 1'b1;
                    waddr_o <= {20'h0, `CSR_MSTATUS};
                    data_o <= {csr_mstatus[31:4], 1'b0, csr_mstatus[2:0]};
                end
                // 中断返回
                S_CSR_MSTATUS_MRET: begin
                    we_o <= 1'b1;
                    waddr_o <= {20'h0, `CSR_MSTATUS};
                    data_o <= {csr_mstatus[31:4], csr_mstatus[7], csr_mstatus[2:0]};
                end
                default: begin
                    we_o <= 1'b0;
                    waddr_o <= 32'h0;
                    data_o <= 32'h0;
                end
            endcase
        end
    end

    // 发出中断信号给ex模块
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            int_assert_o <= 1'b0;
            int_addr_o <= 32'h0;
        end else begin
            case (csr_state)
                // 发出中断进入信号.写完mcause寄存器才能发
                S_CSR_MCAUSE: begin
                    int_assert_o <= 1'b1;
                    int_addr_o <= csr_mtvec;
                end
                // 发出中断返回信号
                S_CSR_MSTATUS_MRET: begin
                    int_assert_o <= 1'b1;
                    int_addr_o <= csr_mepc;
                end
                default: begin
                    int_assert_o <= 1'b0;
                    int_addr_o <= 32'h0;
                end
            endcase
        end
    end

endmodule*/


module clint (
  input logic                   clk         ,
  input logic                   rst_n       ,

  // from cpu lsu:
  input  logic                   clint_ren   ,
  input  logic [`DATA_WIDTH-1:0] clint_raddr ,

  output logic [`DATA_WIDTH-1:0] clint_rdata ,

  input  logic                   clint_wen   ,
  input  logic [`DATA_WIDTH-1:0] clint_waddr ,
  input  logic [`DATA_WIDTH-1:0] clint_wdata ,
  
  // to csr_file:
  output logic                  o_clint_mtip
);

  reg [`DATA_WIDTH-1:0] mtime, mtimecmp; // for both 32bit/64bit arch.

  // read:
  wire ren_mtimecmp, ren_mtime;
  assign ren_mtimecmp = clint_ren & (clint_raddr == `MTIMECMP_ADDR);
  assign ren_mtime    = clint_ren & (clint_raddr == `MTIME_ADDR   );

  assign clint_rdata = ren_mtime ? mtime : (ren_mtimecmp ? mtimecmp : `DATA_WIDTH'b0);

  // write:
  wire lsu_wen_mtime, cnt_wen_mtime, wen_mtimecmp, wen_mtime;

  wire [`DATA_WIDTH-1:0] wdata_mtimecmp, wdata_mtime;

  assign lsu_wen_mtime  = clint_wen & (clint_waddr == `MTIME_ADDR);
  assign cnt_wen_mtime  = !o_clint_mtip;

  assign wen_mtime      = lsu_wen_mtime | cnt_wen_mtime;
  assign wdata_mtime    = lsu_wen_mtime ? clint_wdata : (mtime + 1);
  Reg #(
    .WIDTH     (`DATA_WIDTH    ),
    .RESET_VAL (`DATA_WIDTH'b0 )
  ) reg_mtime (
    .clk     (clk           ),
    .rst_n   (rst_n         ),
    .wen     (wen_mtime     ),
    .din     (wdata_mtime   ),
    .dout    (mtime         )
  );

  assign wen_mtimecmp   = clint_wen & (clint_waddr == `MTIMECMP_ADDR);
  assign wdata_mtimecmp = clint_wdata;
  Reg #(
    .WIDTH     (`DATA_WIDTH    ),
    .RESET_VAL (`DATA_WIDTH'b0 )
  ) reg_mtimcmp (
    .clk     (clk           ),
    .rst_n   (rst_n         ),
    .wen     (wen_mtimecmp  ),
    .din     (wdata_mtimecmp),
    .dout    (mtimecmp      )
  );

  assign o_clint_mtip = (mtime >= mtimecmp);

endmodule