/* Load Store Unit(without AXI interface)
*/

module lsu (
  input                               clk   ,
  input                               rst_n , 
  input         [`LSU_OPT_WIDTH-1:0]  lsu_opt   ,   // lsu i_opt.
  input         [`DATA_WIDTH-1:0]      addr  ,   // mem addr. from exu result.
  input         [`DATA_WIDTH-1:0]      regst ,   // for st.

  output  logic [`DATA_WIDTH-1:0]      regld     // for ld.
);

  wire ren = ~lsu_opt[0];//load instr,need read mem and write to reg files!
  wire [`DATA_WIDTH-1:0] raddr = addr;
  wire [`DATA_WIDTH-1:0] rdata;
  //=============load=========
  always @(*) begin
    case (lsu_opt)
      `LSU_LB:  regld = {{56{rdata[ 7]}}, rdata[ 7:0]};
      `LSU_LH:  regld = {{48{rdata[15]}}, rdata[15:0]};
      `LSU_LW:  regld = {{32{rdata[31]}}, rdata[31:0]};
      `LSU_LD:  regld = rdata;
      `LSU_LBU: regld = {56'b0, rdata[ 7:0]};
      `LSU_LHU: regld = {48'b0, rdata[15:0]};
      `LSU_LWU: regld = {32'b0, rdata[31:0]};
      default:  regld = `DATA_WIDTH'b0;
    endcase
  end

  logic [7:0] mask,wmask;
  logic [`DATA_WIDTH-1:0] waddr,wdata;
  always @(*) begin
    case (lsu_opt)
      `LSU_SB:  mask = 8'b0000_0001;//1 bytes
      `LSU_SH:  mask = 8'b0000_0011;//2 bytes
      `LSU_SW:  mask = 8'b0000_1111;//4 bytes
      `LSU_SD:  mask = 8'b1111_1111;//8 bytes
      default:  mask = 8'b0;
    endcase
  end

//if sequential logic  wmask will delay to wdata
//we can use sequential logic in DPIC write, and signal use comb.
  always@(*)begin
    if(!rst_n)begin
      waddr = `DATA_WIDTH'b0;
      wdata = `DATA_WIDTH'b0;
      wmask = 8'b0;
    end else begin
      waddr = addr;
      wdata = regst;
      wmask = mask;
    end
  end

  //for sim:  ////////////////////////////////////////////////////////////////////////////////////////////
  import "DPI-C" function void rtl_pmem_read (input longint raddr, output longint rdata, input bit ren);
  import "DPI-C" function void rtl_pmem_write(input longint waddr, input longint wdata, input byte wmask);
  always @(*) begin
    rtl_pmem_read (raddr, rdata, ren);//raddr= 80008ff8 rdata=0 ren=0
  end
  
  always@(posedge clk)begin
    rtl_pmem_write(waddr, wdata, wmask);//waddr= 80008ff8 wdata=80000010 wmask=ff
  end

endmodule

