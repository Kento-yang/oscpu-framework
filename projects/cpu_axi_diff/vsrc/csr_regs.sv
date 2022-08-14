`include "rvseed_defines.sv"

// ADDR_CSR寄存器模块
module csr_regs(

    input  logic                                clk,
    input  logic                                rst_n,

//From ID and give ID read data
    output logic     [`DATA_WIDTH-1:0]          id_csr_rdata,              // ib模块读寄存器数据
    input  logic     [`CSR_ADDR_WIDTH-1:0]      id_csr_raddr,               // ib模块读寄存器地址
    input  logic                                id_csr_ren,
  input   logic mret,
//From wb
    input  logic     [`DATA_WIDTH-1:0]          wb_csr_wdata,               // wb模块写寄存器数据
    input  logic     [`CSR_ADDR_WIDTH-1:0]      wb_csr_waddr,               // wb模块写寄存器地址
    input  logic                                wb_csr_wen,                 // wb模块写寄存器标志
//protected csr regfiles.
    input  logic                                mepc_wen      ,   // ecall / iru.
    input  logic     [`DATA_WIDTH-1:0]          mepc_wdata    ,   // ecall / iru.
    input  logic                                mcause_wen    ,   // ecall / iru.
    input  logic     [`DATA_WIDTH-1:0]          mcause_wdata  ,   // ecall / iru.
    input  logic                                mstatus_wen   ,   // ecall / iru.
    input  logic     [`DATA_WIDTH-1:0]          mstatus_wdata   ,   // ecall / iru.
//output csr regs val
    output logic     [`DATA_WIDTH-1:0]          csr_mtvec         ,   // ecall / iru.
    output logic     [`DATA_WIDTH-1:0]          csr_mstatus       ,   // ecall / iru.
    output logic     [`DATA_WIDTH-1:0]          csr_mepc          ,   // mret.
    output logic     [`DATA_WIDTH-1:0]          csr_mip           ,
    output logic     [`DATA_WIDTH-1:0]          csr_mie           ,
    output logic     [`DATA_WIDTH-1:0]          csr_mscratch      ,
// from clint timer interupt
    input  logic                                i_clint_mtip,
// for difftest:
    output logic     [`DATA_WIDTH-1:0]          s_mtvec         ,
    output logic     [`DATA_WIDTH-1:0]          s_mepc          ,
    output logic     [`DATA_WIDTH-1:0]          s_mstatus       ,
    output logic     [`DATA_WIDTH-1:0]          s_sstatus       ,
    output logic     [`DATA_WIDTH-1:0]          s_mcause        ,
    output logic     [`DATA_WIDTH-1:0]          s_mcycle        ,
    output logic     [`DATA_WIDTH-1:0]          s_mie           ,
    output logic     [`DATA_WIDTH-1:0]          s_mip           ,
    output logic     [`DATA_WIDTH-1:0]          s_mscratch      ,
    
    output logic                                global_int_en                 // 全局中断使能标志
     
);   
    logic   [`DATA_WIDTH-1:0]   mepc        ; // Machine exception program counter
    logic   [`DATA_WIDTH-1:0]   mtvec       ; // Machine trap-handler base address
    logic   [`DATA_WIDTH-1:0]   mcause      ; // Machine trap cause
    logic   [`DATA_WIDTH-1:0]   mstatus     ; // Machine status register
    logic   [`DATA_WIDTH-1:0]   mcycle      ; // Machine cycle.
    logic   [`DATA_WIDTH-1:0]   mie         ; // Machine interrupt eanble reg
    logic   [`DATA_WIDTH-1:0]   mip         ; // Machine interrupt pending reg
    logic   [`DATA_WIDTH-1:0]   mscratch    ;    
//------------------------------------------------------------------------------
//  READ CSR REGFILES
//------------------------------------------------------------------------------
    always @ (*) begin
        if (!rst_n) begin
            id_csr_rdata= `DATA_WIDTH'h0;
        end 
        else if(id_csr_ren)begin
            case (id_csr_raddr[11:0])
                `ADDR_CSR_MCYCLE:     id_csr_rdata = mcycle;
                `ADDR_CSR_MTVEC:     id_csr_rdata = mtvec;
                `ADDR_CSR_MCAUSE:    id_csr_rdata = mcause;
                `ADDR_CSR_MEPC:      id_csr_rdata = mepc;
                `ADDR_CSR_MIE:       id_csr_rdata = mie;
                `ADDR_CSR_MIP:       id_csr_rdata = mip;
                `ADDR_CSR_MSTATUS:   id_csr_rdata = mstatus;
                `ADDR_CSR_MSCRATCH:  id_csr_rdata = mscratch;
                default:             id_csr_rdata = `DATA_WIDTH'h0;   
            endcase
        end
        else
            id_csr_rdata = `DATA_WIDTH'h0;
    end

    assign csr_mtvec   = mtvec    ;
    assign csr_mepc    = mepc     ;
    assign csr_mstatus = mstatus  ;
    assign csr_mie     = mie      ;
    assign csr_mip     = mip      ;
    assign csr_mscratch = mscratch;

    assign global_int_en = (mstatus[3] == 1'b1)? 1'b1 : 1'b0;

//------------------------------------------------------------------------------
//  WRITE CSR REGFILES
//------------------------------------------------------------------------------
  // 3.1 mepc: //////////////////////////////////////////////////////////////////////////
  wire wen_mepc = (wb_csr_wen & (wb_csr_waddr == `ADDR_CSR_MEPC)) | mepc_wen ;
  wire [`DATA_WIDTH-1:0] wdata_mepc  = mepc_wen  ? mepc_wdata : wb_csr_wdata;
  
Reg #(
    .WIDTH    (`DATA_WIDTH   ),
    .RESET_VAL(`DATA_WIDTH'b0)
  ) reg_mepc (
    .clk    (clk        ),
    .rst_n  (rst_n      ),
    .wen    (wen_mepc     ),

    .din    (wdata_mepc   ),
    .dout   (mepc         )
  );

  // 3.2 mcause: //////////////////////////////////////////////////////////////////////////
  wire wen_mcause = (wb_csr_wen & (wb_csr_waddr == `ADDR_CSR_MCAUSE )) | mcause_wen ;
  wire [`DATA_WIDTH-1:0] wdata_mcause = mcause_wen ? mcause_wdata : wb_csr_wdata;

Reg #(
    .WIDTH    (`DATA_WIDTH   ),
    .RESET_VAL(`DATA_WIDTH'b0)
  ) reg_mcause (
    .clk    (clk        ),
    .rst_n  (rst_n      ),
    .wen    (wen_mcause     ),
    
    .din    (wdata_mcause   ),
    .dout   (mcause         )
  );

  // 3.3 mtvec: //////////////////////////////////////////////////////////////////////////
  wire wen_mtvec = (wb_csr_wen & (wb_csr_waddr == `ADDR_CSR_MTVEC));
  wire [`DATA_WIDTH-1:0] wdata_mtvec = wb_csr_wdata;

Reg #(
    .WIDTH    (`DATA_WIDTH   ),
    .RESET_VAL(`DATA_WIDTH'b0)
  ) reg_mtvec (
    .clk    (clk        ),
    .rst_n  (rst_n      ),
    .wen    (wen_mtvec     ),
    
    .din    (wdata_mtvec   ),
    .dout   (mtvec         )
  );
  // 3.4 mstatus: //////////////////////////////////////////////////////////////////////////
  wire wen_mstatus = (wb_csr_wen & (wb_csr_waddr == `ADDR_CSR_MSTATUS)) | mstatus_wen ;// mret recover mstatus
  /* verilator lint_off UNOPTFLAT */
  wire [`DATA_WIDTH-1:0] wdata_mstatus;
  assign wdata_mstatus[62:0] = mstatus_wen ? mstatus_wdata[62:0]  : wb_csr_wdata[62:0];
  assign wdata_mstatus[63]   = !((XS == 2'b00) && (FS == 2'b00) && (VS == 2'b00));

Reg #(
    .WIDTH    (`DATA_WIDTH   ),
    .RESET_VAL(`DATA_WIDTH'b0)
  ) reg_mstatus (
    .clk    (clk        ),
    .rst_n  (rst_n      ),
    .wen    (wen_mstatus     ),
    
    .din    (wdata_mstatus   ),
    .dout   (mstatus         )
  );
  // 3.5 mcycle: //////////////////////////////////////////////////////////////////////////
  wire [`DATA_WIDTH-1:0] wdata_mcycle = (wb_csr_wen & (wb_csr_waddr == `ADDR_CSR_MCYCLE)) ? wb_csr_wdata : mcycle+1;

Reg #(
    .WIDTH    (`DATA_WIDTH   ),
    .RESET_VAL(`DATA_WIDTH'b0)
  ) reg_mcycle (
    .clk    (clk        ),
    .rst_n  (rst_n      ),
    .wen    (1'b1      ),
    
    .din    (wdata_mcycle   ),
    .dout   (mcycle         )
  );
  // 3.6 mie: //////////////////////////////////////////////////////////////////////////
  wire wen_mie = (wb_csr_wen & (wb_csr_waddr == `ADDR_CSR_MIE));
  wire [`DATA_WIDTH-1:0] wdata_mie = wb_csr_wdata;

Reg #(
    .WIDTH    (`DATA_WIDTH   ),
    .RESET_VAL(`DATA_WIDTH'b0)
) reg_mie (
    .clk    (clk        ),
    .rst_n  (rst_n      ),
    .wen    (wen_mie     ),
    
    .din    (wdata_mie   ),
    .dout   (mie         )
  );
  // 3.7 mip: //////////////////////////////////////////////////////////////////////////
  assign mip[7] = 0;//i_clint_mtip;//mip include pending interrupts, MTIP = mip[7] 
  wire [`DATA_WIDTH-1:0] wdata_mip = wb_csr_wdata;
  wire wen_mip = (wb_csr_wen & (wb_csr_waddr == `ADDR_CSR_MIP )) ;
  Reg #(
    .WIDTH    (`DATA_WIDTH-1 ),
    .RESET_VAL(0)
  ) reg_mip (
    .clk    (clk        ),
    .rst_n  (rst_n      ),
    .wen    (wen_mip      ),
    .din    ({wdata_mip[`DATA_WIDTH-1:8], wdata_mip[6:0]}),
    .dout   ({      mip[`DATA_WIDTH-1:8],          mip[6:0]})
  );
  // 3.8 mscratch: //////////////////////////////////////////////////////////////////////////
  wire wen_mscratch = (wb_csr_wen & (wb_csr_waddr == `ADDR_CSR_MSCRATCH )) ;
  wire [`DATA_WIDTH-1:0] wdata_mscratch = wb_csr_wdata;
  Reg #(
    .WIDTH    (`DATA_WIDTH-1 ),
    .RESET_VAL(0)
  ) reg_mscratch (
    .clk    (clk        ),
    .rst_n  (rst_n      ),
    .wen    (wen_mscratch      ),
    .din    (wdata_mscratch),
    .dout   (mscratch)
  );

  // 4. use for difftest sim :///////////////////////////////////////////////////////////
  assign s_mepc   = wen_mepc    ? wdata_mepc   : mepc    ;
  assign s_mcause = wen_mcause  ? wdata_mcause : mcause  ;
  assign s_mtvec  = wen_mtvec   ? wdata_mtvec  : mtvec   ;
  wire [1:0] XS = wen_mstatus ? wdata_mstatus[16:15] : mstatus[16:15],
             FS = wen_mstatus ? wdata_mstatus[14:13] : mstatus[14:13],
             VS = wen_mstatus ? wdata_mstatus[10: 9] : mstatus[10: 9];
  
  assign s_mstatus[63] =  !((XS == 2'b00) && (FS == 2'b00) && (VS == 2'b00));
  assign s_sstatus[63] =  !((XS == 2'b00) && (FS == 2'b00) && (VS == 2'b00));
  assign s_sstatus[16:15] = XS;
  assign s_sstatus[14:13] = FS;
  assign s_sstatus[10: 9] = VS;
  assign s_mstatus [62:0]= wen_mstatus ? wdata_mstatus[62:0]: mstatus[62:0];
  assign s_mcycle = wdata_mcycle;
  assign s_mie    = wen_mie     ? wdata_mie    : mie     ;
  assign s_mip    = wen_mip     ? wb_csr_wdata : mip     ; //{wb_csr_wdata[`DATA_WIDTH-1:8],mip[7],wb_csr_wdata[6:0]} : mip ;
  assign s_mscratch = wen_mscratch ? wdata_mscratch : mscratch;
endmodule