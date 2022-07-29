//import "DPI-C" function void set_gpr_ptr(input logic [63:0] a []);
`include "rvseed_defines.sv"
module reg_file (
    input                                 clk,
    input                                 rst_n,
    input                                 reg_wen,
    input       [`DATA_WIDTH-1:0]         reg_wdata,
    input       [`REG_ADDR_WIDTH-1:0]     reg_waddr,


    input      [`REG_ADDR_WIDTH-1:0]      reg1_raddr, // register 1 read address
    input      [`REG_ADDR_WIDTH-1:0]      reg2_raddr, // register 2 read address
    
    output logic [`DATA_WIDTH-1:0]          reg1_rdata, // register 1 read data
    output logic [`DATA_WIDTH-1:0]          reg2_rdata,  // register 2 read data

    output logic [`DATA_WIDTH-1:0]            reg10_a0
);

    logic [`DATA_WIDTH-1:0] reg_f [0:`REG_NUM-1];//64bit * 32个

    //good bad trap judge
    assign reg10_a0 = reg_f[10];


    //reg write
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            reg_f[reg_waddr] <= 0;
        else if (reg_wen && (reg_waddr != `REG_ADDR_WIDTH'b0)) //reg0 == 0 forever
            reg_f[reg_waddr] <= reg_wdata;
    end


  // register 1 read
    always @(*) begin
        if(reg1_raddr == `REG_ADDR_WIDTH'b0)
            reg1_rdata = `DATA_WIDTH'b0;//寄存器0始终为0
        else
            reg1_rdata = reg_f[reg1_raddr];
    end

// register 2 read
    always @(*) begin
        if(reg2_raddr == `REG_ADDR_WIDTH'b0)
            reg2_rdata = `DATA_WIDTH'b0;
        else
            reg2_rdata = reg_f[reg2_raddr];
    end

//DPI-C传递寄存器引用
    //initial set_gpr_ptr(reg_f);  // reg_f为通用寄存器的二维数组变量
    
endmodule