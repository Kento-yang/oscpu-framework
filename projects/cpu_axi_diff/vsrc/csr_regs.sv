`include "rvseed_defines.sv"

// CSR寄存器模块
module csr_regs(

    input  logic                 clk,
    input  logic                 rst_n,

    // form wb
    input  logic                 wb_csr_wen,                        // wb模块写寄存器标志
    input  logic     [31:0]      wb_csr_raddr,               // wb模块读寄存器地址
    input  logic     [31:0]      wb_csr_waddr,               // wb模块写寄存器地址
    input  logic     [31:0]      wb_csr_wdata,             // wb模块写寄存器数据

    // from clint
    input  logic                 clint_we_i,                  // clint模块写寄存器标志
    input  logic     [31:0]      clint_raddr_i,      // clint模块读寄存器地址
    input  logic     [31:0]      clint_waddr_i,      // clint模块写寄存器地址
    input  logic     [31:0]      clint_data_i,       // clint模块写寄存器数据

    output logic                 global_int_en_o,            // 全局中断使能标志

    // to clint
    output logic     [31:0]      clint_data_o,       // clint模块读寄存器数据
    output logic     [31:0]      clint_csr_mtvec,    // mtvec
    output logic     [31:0]      clint_csr_mepc,     // mepc
    output logic     [31:0]      clint_csr_mstatus,  // mstatus
 
    // to wb 
    output logic     [31:0]      wb_csr_rdata              // wb模块读寄存器数据
);

    logic [63:0] cycle;
    logic [31:0] mtvec;
    logic [31:0] mcause;
    logic [31:0] mepc;
    logic [31:0] mie;
    logic [31:0] mstatus;
    logic [31:0] mscratch;

    assign global_int_en_o = (mstatus[3] == 1'b1)? 1'b1 : 1'b0;

    assign clint_csr_mtvec = mtvec;
    assign clint_csr_mepc = mepc;
    assign clint_csr_mstatus = mstatus;

    // cycle counter
    // 复位撤销后就一直计数
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle <= {32'h0, 32'h0};
        end else begin
            cycle <= cycle + 1'b1;
        end
    end

    // write reg
    // 写寄存器操作
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mtvec <= 32'h0;
            mcause <= 32'h0;
            mepc <= 32'h0;
            mie <= 32'h0;
            mstatus <= 32'h0;
            mscratch <= 32'h0;
        end else begin
            // 优先响应ex模块的写操作
            if (wb_csr_wen == 1'b1) begin
                case (wb_csr_waddr[11:0])
                    `CSR_MTVEC: begin
                        mtvec <= wb_csr_wdata;
                    end
                    `CSR_MCAUSE: begin
                        mcause <= wb_csr_wdata;
                    end
                    `CSR_MEPC: begin
                        mepc <= wb_csr_wdata;
                    end
                    `CSR_MIE: begin
                        mie <= wb_csr_wdata;
                    end
                    `CSR_MSTATUS: begin
                        mstatus <= wb_csr_wdata;
                    end
                    `CSR_MSCRATCH: begin
                        mscratch <= wb_csr_wdata;
                    end
                    default:;
                endcase
            // clint模块写操作
            end else if (clint_we_i == 1'b1) begin
                case (clint_waddr_i[11:0])
                    `CSR_MTVEC: begin
                        mtvec <= clint_data_i;
                    end
                    `CSR_MCAUSE: begin
                        mcause <= clint_data_i;
                    end
                    `CSR_MEPC: begin
                        mepc <= clint_data_i;
                    end
                    `CSR_MIE: begin
                        mie <= clint_data_i;
                    end
                    `CSR_MSTATUS: begin
                        mstatus <= clint_data_i;
                    end
                    `CSR_MSCRATCH: begin
                        mscratch <= clint_data_i;
                    end
                    default:;
                endcase
            end
        end
    end

    // read reg
    // ex模块读CSR寄存器
    always @ (*) begin
        if ((wb_csr_waddr[11:0] == wb_csr_raddr[11:0]) && (wb_csr_wen == 1'b1)) begin
            wb_csr_rdata= wb_csr_wdata;
        end else begin
            case (wb_csr_raddr[11:0])
                `CSR_CYCLE: begin
                    wb_csr_rdata= cycle[31:0];
                end
                `CSR_CYCLEH: begin
                    wb_csr_rdata= cycle[63:32];
                end
                `CSR_MTVEC: begin
                    wb_csr_rdata= mtvec;
                end
                `CSR_MCAUSE: begin
                    wb_csr_rdata= mcause;
                end
                `CSR_MEPC: begin
                    wb_csr_rdata= mepc;
                end
                `CSR_MIE: begin
                    wb_csr_rdata= mie;
                end
                `CSR_MSTATUS: begin
                    wb_csr_rdata= mstatus;
                end
                `CSR_MSCRATCH: begin
                    wb_csr_rdata= mscratch;
                end
                default: begin
                    wb_csr_rdata= 32'h0;
                end
            endcase
        end
    end

    // read reg
    // clint模块读CSR寄存器
    always @ (*) begin
        if ((clint_waddr_i[11:0] == clint_raddr_i[11:0]) && (clint_we_i == 1'b1)) begin
            clint_data_o = clint_data_i;
        end else begin
            case (clint_raddr_i[11:0])
                `CSR_CYCLE: begin
                    clint_data_o = cycle[31:0];
                end
                `CSR_CYCLEH: begin
                    clint_data_o = cycle[63:32];
                end
                `CSR_MTVEC: begin
                    clint_data_o = mtvec;
                end
                `CSR_MCAUSE: begin
                    clint_data_o = mcause;
                end
                `CSR_MEPC: begin
                    clint_data_o = mepc;
                end
                `CSR_MIE: begin
                    clint_data_o = mie;
                end
                `CSR_MSTATUS: begin
                    clint_data_o = mstatus;
                end
                `CSR_MSCRATCH: begin
                    clint_data_o = mscratch;
                end
                default: begin
                    clint_data_o = 32'h0;
                end
            endcase
        end
    end

endmodule