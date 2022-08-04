//a.在一个周期开始，EX 阶段要使用上一条处在 EX 阶段指令的执行结果，此时我们将 EX/MEM 寄存器的数据前递。
//b.在一个周期开始，EX 阶段要使用上一条处在 MEM 阶段指令的执行结果，此时我们将 reg_waddr_exMEM/WB 寄存器的数据前递。
//c.在一个周期开始，EX 阶段要使用上一条处在 WB 阶段指令的执行结果，此时不需要前递（寄存器堆前递机制）
//d.在第一种情况下，如果是上一条是访存指令，即发生加载—使用型冒险。则需要停顿一个周期。
//e.在发生加载——使用型冒险的时候，如果是load后跟着store指令，并且load指令的rd与store指令的rs1不同而与rs2相同，
//则不需要停顿，只需要将MEM/WB 寄存器的数据前递到MEM阶段。
`include "rvseed_defines.sv"
module data_bypass(
    input   [`REG_ADDR_WIDTH-1:0]   reg1_raddr_id                ,
    input   [`REG_ADDR_WIDTH-1:0]   reg2_raddr_id                ,
    input   [`REG_ADDR_WIDTH-1:0]   reg1_raddr_ex                ,
    input   [`REG_ADDR_WIDTH-1:0]   reg2_raddr_ex                ,	

    input   [`REG_ADDR_WIDTH-1:0]   reg_waddr_ex                ,
    input   [`REG_ADDR_WIDTH-1:0]   reg_waddr_mem                ,
    input   [`REG_ADDR_WIDTH-1:0]   reg_waddr_wb            , 

    input                           reg_wen_ex              ,
    input                           reg_wen_mem              ,
    input                           reg_wen_wb              ,

    input   [`LSU_OPT_WIDTH-1:0]    sten_ex           ,//ex阶段st指令
    input   [`LSU_OPT_WIDTH-1:0]    sten_mem           ,//mem阶段st指令
    input                           lden_id,
    input                           lden_ex,
    input                           lden_mem           ,//mem阶段ld指令
    
    output  logic                   bubble_id_ex ,
    output  logic   [   2:0]        bp_alu_src1_ctrl           ,//1X:EX/MEM bypass, 01:MEM/WB bypass, 00:needn't bypass
    output  logic   [   2:0]        bp_alu_src2_ctrl           ,
    output  logic                   bp_ld_st_ctrl               
);
	//若多位均为高电平，bypass优先级：wb/regfile < MEM/WB < ex/mem ，ex/mem是最近的指令，依赖也最新因此仲裁优先级最高。

    assign bp_alu_src1_ctrl[2] = (reg_wen_ex && (reg_waddr_ex != 5'd0) &&(reg_waddr_ex == reg1_raddr_id));
    assign bp_alu_src1_ctrl[1] = (reg_wen_mem && (reg_waddr_mem != 5'd0) &&(reg_waddr_mem == reg1_raddr_id));
    assign bp_alu_src1_ctrl[0] = (reg_wen_wb && (reg_waddr_wb != 5'd0) &&(reg_waddr_wb == reg1_raddr_id));
    
    assign bp_alu_src2_ctrl[2] = (reg_wen_ex && (reg_waddr_ex != 5'd0) &&(reg_waddr_ex == reg2_raddr_id));
	assign bp_alu_src2_ctrl[1] = (reg_wen_mem && (reg_waddr_mem != 5'd0) &&(reg_waddr_mem == reg2_raddr_id));
    assign bp_alu_src2_ctrl[0] = (reg_wen_wb && (reg_waddr_wb != 5'd0) &&(reg_waddr_wb == reg2_raddr_id));

    //ld-add bubble
    //mem阶段ld，且写回数据与下一条指令的源寄存器冲突
    //在总线中，这块会有问题，Lbu a0，a0由于总线执行一次指令较长，会产生假bubble
    //解决办法：让lden_ex改为lden_ex && lden_id 不解决LD-LD类型冒险。
    //
    //
    assign bubble_id_ex = lden_ex && !lden_id && reg_wen_ex && (reg_waddr_ex != 5'd0) && ( (reg_waddr_ex == reg1_raddr_id ) || (reg_waddr_ex == reg2_raddr_id));//需停顿一拍

    //ld-st mem2ex
    assign bp_ld_st_ctrl = (lden_mem && sten_ex[0] && (sten_ex != `LSU_NOP))//mem_wb ld / ex_mem st
                            && reg_wen_mem && (reg_waddr_mem != 5'd0) 
                            && (reg_waddr_mem != reg1_raddr_ex ) && (reg_waddr_mem == reg2_raddr_ex) ;//st
    

	
endmodule
