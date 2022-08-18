//merge 2 SRAM to 1 icache ram.
`include "rvseed_defines.sv"
module icache_ram(
    Q, CLK, CEN, WEN, A, D
);
parameter Bits = 128;
parameter Word_Depth = 64;
parameter Add_Width = 7;

output  reg [Bits-1:0]      Q;//读数据
input                   CLK;
input                   CEN;//低电平有效使能
input                   WEN;//写使能，低电平有效
input   [Add_Width-1:0] A;//读写地址
input   [Bits-1:0]      D;//写数据

    wire CS;//Chip Selecttion 
    logic [Bits-1:0] Q0, Q1;

    assign CS = A[Add_Width-1] ? 1 : 0;

    assign Q = CS ? Q1 : Q0;

    wire WEN0, WEN1;
    assign WEN0 = CS ? 1'b1 : WEN;
    assign WEN1 = CS ? WEN  : 1'b1;

S011HD1P_X32Y2D128 u_way0_0(.Q(Q0 ), .CLK (CLK), .CEN (CEN), .WEN (WEN0 ), .A(A[Add_Width-2:0]), .D(D) );//low 64
S011HD1P_X32Y2D128 u_way0_1(.Q(Q1 ), .CLK (CLK), .CEN (CEN), .WEN (WEN1 ), .A(A[Add_Width-2:0]), .D(D) );//high 64

endmodule