`include "rvseed_defines.sv"
module mem_stage(
    input                               clk                        ,
    input                               rst_n                      ,
//from exe stage
    input       [`INST_WIDTH-1:0]       ex_inst                    ,
    input                               ex_reg_wen                 ,
    input       [`REG_ADDR_WIDTH-1:0]   ex_reg_waddr               ,// register write address
    input       [`DATA_WIDTH-1:0]       ex_alu_res                 ,
    input       [`DATA_WIDTH-1:0]       ex_regst                   ,//ex_regst
    input       [`LSU_OPT_WIDTH-1:0]    ex_lsu_opt                 ,
    input ex_lsu_lden,
    input ex_lsu_sten,
    input       [`PC_WIDTH-1:0]         ex_diff_pc                 ,
//r/w data memory from/to axi_rw
    output wire                         mem_valid_o,
    input  wire                         mem_ready_i,
    output wire                         mem_rw_req_o,//1：write to mem 0：read from mem
    input  wire [`AXI_DATA_WIDTH-1: 0]  mem_data_read_i,
    output wire [`AXI_DATA_WIDTH-1: 0]  mem_data_write_o,           // rs2 from previous stage
    output wire [`AXI_ADDR_WIDTH-1: 0]  mem_rw_addr_i,           // compute result from previous stage
    output wire [1:0]                   mem_rw_size_o,
    input       [1:0]                   mem_rw_resp_i,
    output wire [`AXI_DATA_WIDTH/8-1:0] mem_write_mask_o,
//to next stage
    output      [`INST_WIDTH-1:0]       mem_inst                   ,
    output                              mem_reg_wen                ,
    output      [`REG_ADDR_WIDTH-1:0]   mem_reg_waddr              ,// register write address
    output      [`DATA_WIDTH-1:0]       mem_alu_res                ,
    output      [`LSU_OPT_WIDTH-1:0]    mem_lsu_opt                ,
    output                              mem_lsu_lden,
    output                              mem_lsu_sten,
    output      [`PC_WIDTH-1:0]         mem_diff_pc                ,

    output logic     [`DATA_WIDTH-1:0]       mem_regld                  ,

    //output                              mem_hold, //to WBU, stall the pipeline

    output logic lsu_valid,
//handshake signal
    input                               valid_ex2mem               ,
    input                               ready_wb2mem               ,

    output                              valid_mem2wb               ,
    output                              ready_mem2ex                

);
    //logic mem_lden, mem_sten, mem_ldst_en;
    //assign mem_lden = ((mem_lsu_opt == `LSU_LB) || (mem_lsu_opt == `LSU_LH) || (mem_lsu_opt == `LSU_LW) || (mem_lsu_opt == `LSU_LD) || 
                      //(mem_lsu_opt == `LSU_LBU) || (mem_lsu_opt == `LSU_LHU) || (mem_lsu_opt == `LSU_LWU)) ? 1 : 0 ;

    //assign mem_sten = ((mem_lsu_opt == `LSU_SB) || (mem_lsu_opt == `LSU_SH) || (mem_lsu_opt == `LSU_SW) || (mem_lsu_opt == `LSU_SD)) ? 1 : 0 ;
    //assign mem_ldst_en = mem_lden | mem_sten;
//------------------------------------------------------------------------------
//  EX-MEM REG  
//------------------------------------------------------------------------------
   wire                                pipe_wen = valid_ex2mem && ready_mem2ex;
   //logic    [`DATA_WIDTH-1:0]           ex_alu_res;
   logic    [`DATA_WIDTH-1:0]           mem_reg2_rdata;


ex_mem u_ex_mem(
    .clk                               (clk                       ),
    .rst_n                             (rst_n                     ),
    .pipe_wen                          (pipe_wen                  ),
    
    .ex_inst                           (ex_inst                   ),
    .ex_reg_wen                        (ex_reg_wen                ),
    .ex_reg_waddr                      (ex_reg_waddr              ),
    .ex_alu_res                        (ex_alu_res                ),
    .ex_reg2_rdata                     (ex_regst                  ),
    .ex_lsu_opt                        (ex_lsu_opt                ),
    .ex_lsu_lden(ex_lsu_lden),
    .ex_lsu_sten(ex_lsu_sten),
    .ex_diff_pc                        (ex_diff_pc                ),

    .mem_inst                          (mem_inst                  ),
    .mem_reg_wen                       (mem_reg_wen               ),
    .mem_reg_waddr                     (mem_reg_waddr             ),
    .mem_alu_res                       (mem_alu_res               ),
    .mem_reg2_rdata                    (mem_reg2_rdata            ),
    .mem_lsu_opt                       (mem_lsu_opt               ),
    .mem_lsu_lden(mem_lsu_lden),
    .mem_lsu_sten(mem_lsu_sten),
    .mem_diff_pc                       (mem_diff_pc               ) 
);
//------------------------------------------------------------------------------
//  MEM-AXI_RW  
//------------------------------------------------------------------------------
    logic handshake_done;
    assign handshake_done = mem_valid_o & mem_ready_i;

    always @(*) begin
      if(!rst_n)
          lsu_valid = 1'b0;
      else if(!handshake_done && mem_lsu_opt != `LSU_NOP && mem_lsu_opt != 'h0)
          lsu_valid = 1'b0;
      else
          lsu_valid = 1'b1;
    end

    assign mem_valid_o   =  mem_lsu_lden | mem_lsu_sten; //ld or st occupy the axi
    assign mem_rw_req_o  =  mem_lsu_sten ;//1:store(write), 0：load(read)
    assign mem_rw_addr_i =  mem_alu_res;

//READ FROM AXI_RW
    assign rdata = (handshake_done)? mem_data_read_i : 64'h0;

//WRITE TO AXI_RW
    assign mem_data_write_o = mem_reg2_rdata;
    assign mem_write_mask_o = wmask; 
    assign mem_rw_size_o = axi_size;//axi wirte size

//------------------------------------------------------------------------------
//  4.MEM  
//------------------------------------------------------------------------------
    logic   [`DATA_WIDTH-1:0]           rdata;
    logic   [`AXI_DATA_WIDTH/8-1:0]     wmask;
    logic   [1:0]                       axi_size;

  wire [`DATA_WIDTH-1:0] raddr = mem_alu_res;
  
  //=============load=========
  always @(*) begin
    case (mem_lsu_opt)//rdata->load data
      `LSU_LB:  begin mem_regld = {{56{rdata[ 7]}}, rdata[ 7:0]}; axi_size = `SIZE_B;end
      `LSU_LH:  begin mem_regld = {{48{rdata[15]}}, rdata[15:0]}; axi_size = `SIZE_H;end 
      `LSU_LW:  begin mem_regld = {{32{rdata[31]}}, rdata[31:0]}; axi_size = `SIZE_W;end 
      `LSU_LD:  begin mem_regld = rdata;                          axi_size = `SIZE_D;end
      `LSU_LBU: begin mem_regld = {56'b0, rdata[ 7:0]};           axi_size = `SIZE_B;end
      `LSU_LHU: begin mem_regld = {48'b0, rdata[15:0]};           axi_size = `SIZE_H;end
      `LSU_LWU: begin mem_regld = {32'b0, rdata[31:0]};           axi_size = `SIZE_W;end
      default:  begin mem_regld = `DATA_WIDTH'b0;                 axi_size = `SIZE_B;end
    endcase
  end

  logic [`DATA_WIDTH-1:0] wdata;
  always @(*) begin
    case (mem_lsu_opt)
      `LSU_SB:  wmask = 8'b0000_0001;//1 bytes
      `LSU_SH:  wmask = 8'b0000_0011;//2 bytes
      `LSU_SW:  wmask = 8'b0000_1111;//4 bytes
      `LSU_SD:  wmask = 8'b1111_1111;//8 bytes
      default:  wmask = 8'b0;
    endcase
  end


//handshake
    logic valid_mem2wb_r, ready_mem2ex_r;

    assign valid_mem2wb = valid_mem2wb_r && lsu_valid;
    assign ready_mem2ex = ready_mem2ex_r && lsu_valid;
pipehandshake u_pipehandshake(
    .clk          ( clk          ),
    .rst_n        ( rst_n        ),
    .valid_pre_i  ( valid_ex2mem  ),
    .ready_next_i ( ready_wb2mem ),
    .valid_o_next ( valid_mem2wb_r ),
    .ready_o_pre  ( ready_mem2ex_r  )
);
/*lsu u0_lsu(
    .clk                               (clk                       ),
    .rst_n                             (rst_n                     ),

    .lsu_opt                           (mem_lsu_opt               ),// lsu i_opt.
    .addr                              (mem_alu_res               ),// mem i_addr. from exu result.
    //regst                             (mem_reg2_rdata            ),// for st. M[x[rs1]+imm]X[rs2][63:0]
    
    .rdata                             (rdata                     ),

    .wmask                             (wmask                     ),
    .axi_size                          (axi_size                  ),
    .regld                             (mem_regld                 ) // for ld.
);*/
 //wire ren = ~lsu_opt[0];//load instr,need read mem and write to reg files!

endmodule