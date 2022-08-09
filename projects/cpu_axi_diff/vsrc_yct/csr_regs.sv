`include "rvseed_defines.sv"

// ADDR_CSR寄存器模块
module csr_regs(

    input  logic                 clk,
    input  logic                 rst_n,

    //From ID and give ID read data
    output logic     [`DATA_WIDTH-1:0]          id_csr_rdata,              // ib模块读寄存器数据
    input  logic     [`CSR_ADDR_WIDTH-1:0]      id_csr_raddr,               // ib模块读寄存器地址
    input  logic                                id_csr_ren,

    //From wb
    input  logic     [`DATA_WIDTH-1:0]          wb_csr_wdata,               // wb模块写寄存器数据
    input  logic     [`CSR_ADDR_WIDTH-1:0]      wb_csr_waddr,               // wb模块写寄存器地址
    input  logic                                wb_csr_wen,                 // wb模块写寄存器标志

    // from clint
    input  logic                                i_clint_mtip,
    
    input  logic                                clint_we_i,                  // clint模块写寄存器标志
    input  logic     [`CSR_ADDR_WIDTH:0]        clint_waddr_i,      // clint模块写寄存器地址
    input  logic     [`DATA_WIDTH-1:0]          clint_wdata_i,       // clint模块写寄存器数据

    // to clint
    output logic     [`DATA_WIDTH-1:0]          csr_mtvec         ,   // ecall / iru.
    output logic     [`DATA_WIDTH-1:0]          csr_mstatus       ,   // ecall / iru.
    output logic     [`DATA_WIDTH-1:0]          csr_mepc          ,   // mret.
    //for difftest
    output logic     [`DATA_WIDTH-1:0]          csr_mcause        ,   // mret.
    output logic     [`DATA_WIDTH-1:0]          csr_mie           ,
    output logic     [`DATA_WIDTH-1:0]          csr_mscratch      ,

    output logic                                global_int_en     ,            // 全局中断使能标志

    output logic     [`DATA_WIDTH-1:0]          csr_mtie           ,
           
   
);   


    logic   [`DATA_WIDTH-1:0]   mepc        ; // Machine exception program counter
    logic   [`DATA_WIDTH-1:0]   mtvec       ; // Machine trap-handler base address
    logic   [`DATA_WIDTH-1:0]   mcause      ; // Machine trap cause
    logic   [`DATA_WIDTH-1:0]   mstatus     ; // Machine status register
    logic   [`DATA_WIDTH-1:0]   cycleCnt    ; // Machine cycle.
    logic   [`DATA_WIDTH-1:0]   mie         ; // Machine interrupt eanble reg
    logic   [`DATA_WIDTH-1:0]   mip         ; // Machine interrupt pending reg
    //logic   [`DATA_WIDTH-1:0]   mscratch    ;    

    //to clint
    assign csr_mtvec     = ((wb_csr_waddr == `ADDR_CSR_MTVEC) && wb_csr_wen)    ?   wb_csr_wdata : mtvec;
    assign csr_mepc      = ((wb_csr_waddr == `ADDR_CSR_MEPC ) && wb_csr_wen)    ?   wb_csr_wdata : mepc;

    assign csr_mstatus   = ((clint_waddr_i == `ADDR_CSR_MSTATUS) && clint_we_i) ? clint_wdata_i: 
                           ((wb_csr_waddr  == `ADDR_CSR_MSTATUS) && wb_csr_wen && fetched)?
                           {(wb_csr_wdata[14:13]==2'b11 || wb_csr_wdata[16:15]==2'b11),wb_csr_wdata[62:0]} : mstatus;
                            
    assign csr_mcause    = ((clint_waddr_i == `ADDR_CSR_MCAUSE) && clint_we_i)  ?   clint_wdata_i: 
                            (waddr_i == `ADDR_CSR_MCAUSE    && write_ena)       ?   wdata_i : mcause;

    assign csr_mie       = ((waddr_i == `ADDR_CSR_MIE)      && write_ena)       ?   wdata_i : mie;
    assign csr_mscratch  = ((waddr_i == `ADDR_CSR_MSCRATCH) && write_ena)       ?   wdata_i : mscratch;

    assign global_int_en = (mstatus[3] == 1'b1)? 1'b1 : 1'b0;
    assign mtie          = (mie[7] == 1'b1)    ? 1'b1 : 1'b0;

    assign mip[7] =  i_clint_mtip;//mip include pending interrupts, MTIP = mip[7] 


    // cycle counter while no rst_n
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycleCnt <= `DATA_WIDTH'h0;;
        end 
        else if(wb_csr_wen && wb_csr_waddr == `ADDR_CSR_MCYCLE)begin
            cycleCnt <= wb_csr_wdata;
        end
        else begin
            cycleCnt <= cycle + 1'b1;
        end
    end

    // write csr reg
    always @ (posedge clk or negedge rst_n) begin 
        if (!rst_n) begin
            mepc     <= `DATA_WIDTH'h0;
            mtvec    <= `DATA_WIDTH'h0;
            mcause   <= `DATA_WIDTH'h0;
            mstatus  <= `DATA_WIDTH'h0;
            mie      <= `DATA_WIDTH'h0;
            mip      <= `DATA_WIDTH'h0;
            mscratch <= `DATA_WIDTH'h0;
        end else begin
            // 优先响应ex模块的写操作
            if (wb_csr_wen) begin
                case (wb_csr_waddr)
                    `ADDR_CSR_MEPC:      mepc     <= {(wb_csr_wdata[14:13]==2'b11 || wb_csr_wdata[16:15]==2'b11),wb_csr_wdata[62:0]};
                    `ADDR_CSR_MTVEC:     mtvec    <= wb_csr_wdata;
                    `ADDR_CSR_MCAUSE:    mcause   <= wb_csr_wdata;
                    `ADDR_CSR_MSTATUS:   mstatus  <= wb_csr_wdata;
                    `ADDR_CSR_MIE:       mie      <= wb_csr_wdata;
                    `ADDR_CSR_MIP:       {mip[63:8],mip[6:0]} <= {wb_csr_wdata[63:8],wb_csr_wdata[6:0]};
                    `ADDR_CSR_MSCRATCH:  mscratch <= wb_csr_wdata;
                    default:;
                endcase
            // clint模块写操作
            end else if (clint_we_i) begin
                case (clint_waddr_i)
                    `ADDR_CSR_MEPC:      mepc     <= clint_data_i;
                    `ADDR_CSR_MTVEC:     mtvec    <= clint_data_i;
                    `ADDR_CSR_MCAUSE:    mcause   <= clint_data_i; 
                    `ADDR_CSR_MSTATUS:   mstatus  <= clint_data_i;
                    `ADDR_CSR_MIE:       mie      <= clint_data_i;
                    `ADDR_CSR_MIP:       mip      <= clint_data_i;
                    `ADDR_CSR_MSCRATCH:  mscratch <= clint_data_i;    
                    default:;
                endcase
            end
        end
    end

    // read csr reg
    always @ (*) begin
        if (!rst_n) begin
            csr_rdata= `DATA_WIDTH'h0;
        end 
        else if(id_csr_ren)begin
            case (id_csr_raddr[11:0])
                `ADDR_CSR_CYCLE:     csr_rdata= cycle[31:0];
                `ADDR_CSR_CYCLEH:    csr_rdata= cycle[63:32];
                `ADDR_CSR_MTVEC:     csr_rdata= mtvec;
                `ADDR_CSR_MCAUSE:    csr_rdata= mcause;
                `ADDR_CSR_MEPC:      csr_rdata= mepc;
                `ADDR_CSR_MIE:       csr_rdata= mie;
                `ADDR_CSR_MIP:       csr_rdata= mip;
                `ADDR_CSR_MSTATUS:   csr_rdata= mstatus;
                `ADDR_CSR_MSCRATCH:  csr_rdata= mscratch;
                default:             csr_rdata= `DATA_WIDTH'h0;   
            endcase
        end
        else
            csr_rdata = `DATA_WIDTH'h0;
    end


endmodule