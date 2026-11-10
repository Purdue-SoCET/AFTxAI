`ifndef AFT_TOP_IF_SV
`define AFT_TOP_IF_SV

interface aft_top_if;
    // Clocks and Resets
    logic HCLK;
    logic HRESETn;

    // Testbench bus master interface (replacing the core for S3)
    // Core is AHB manager 0
    logic        tb_hsel; // Not strictly part of manager, but good to have
    logic [31:0] tb_haddr;
    logic [31:0] tb_hwdata;
    logic [3:0]  tb_hwstrb;
    logic        tb_hwrite;
    logic [2:0]  tb_hsize;
    logic [2:0]  tb_hburst;
    logic [1:0]  tb_htrans;
    logic        tb_hmastlock;
    
    logic [31:0] tb_hrdata;
    logic        tb_hready;
    logic        tb_hresp;

    // Off-chip SRAM pins (Separated out from sram_if for standard top-level routing, per TOP-PIN-001)
    logic [18:0] sram_addr;
    logic [15:0] sram_wdata;
    logic [15:0] sram_rdata;
    logic        sram_pad_oe;
    logic        sram_ce0_n;
    logic        sram_oe0_n;
    logic        sram_we0_n;
    logic        sram_ub0_n;
    logic        sram_lb0_n;
    logic        sram_ce1_n;
    logic        sram_oe1_n;
    logic        sram_we1_n;
    logic        sram_ub1_n;
    logic        sram_lb1_n;

endinterface

`endif
