`timescale 1ns/1ps
import aft_map_pkg::*;

module aft_top (
    aft_top_if intf
);

    // =========================================================================
    // Clock and Reset Generation
    // =========================================================================
    logic hclk, hresetn;
    logic pclk, presetn;

    soc_clk_rst u_soc_clk_rst (
        .ext_clk_i   (intf.HCLK),
        .ext_rst_n_i (intf.HRESETn),
        .hclk_o      (hclk),
        .hresetn_o   (hresetn),
        .pclk_o      (pclk),
        .presetn_o   (presetn)
    );

    // =========================================================================
    // AHB Fabric
    // =========================================================================
    localparam int NMANAGERS = 2;
    localparam int NSUBORDINATES = 4;

    ahb_if manager_ports [NMANAGERS](.HCLK(hclk), .HRESETn(hresetn));
    ahb_if subordinate_ports [NSUBORDINATES](.HCLK(hclk), .HRESETn(hresetn));

    // Manager 0: Testbench Bus Master (Replacing Core for S3)
    assign manager_ports[0].HADDR     = intf.tb_haddr;
    assign manager_ports[0].HWDATA    = intf.tb_hwdata;
    assign manager_ports[0].HWSTRB    = intf.tb_hwstrb;
    assign manager_ports[0].HWRITE    = intf.tb_hwrite;
    assign manager_ports[0].HSIZE     = intf.tb_hsize;
    assign manager_ports[0].HBURST    = intf.tb_hburst;
    assign manager_ports[0].HTRANS    = intf.tb_htrans;
    assign manager_ports[0].HMASTLOCK = intf.tb_hmastlock;
    // Note: The interconnect generates HREADY and HRESP for managers.
    assign intf.tb_hrdata = manager_ports[0].HRDATA;
    assign intf.tb_hready = manager_ports[0].HREADY;
    assign intf.tb_hresp  = manager_ports[0].HRESP;

    // Manager 1: Unused (DMA in S6)
    assign manager_ports[1].HADDR     = '0;
    assign manager_ports[1].HWDATA    = '0;
    assign manager_ports[1].HWSTRB    = '0;
    assign manager_ports[1].HWRITE    = '0;
    assign manager_ports[1].HSIZE     = '0;
    assign manager_ports[1].HBURST    = '0;
    assign manager_ports[1].HTRANS    = '0; // IDLE
    assign manager_ports[1].HMASTLOCK = '0;

    localparam logic [31:0] AHB_MAP [NSUBORDINATES] = '{
        BOOT_ROM_BASE,
        ON_CHIP_RAM_BASE,
        OFF_CHIP_SRAM_BASE,
        APB_BRIDGE_BASE
    };

    ahb_interconnect #(
        .NMANAGERS(NMANAGERS),
        .NSUBORDINATES(NSUBORDINATES),
        .AHB_MAP(AHB_MAP),
        .HDATA_WIDTH(32)
    ) u_ahb_interconnect (
        .HCLK(hclk),
        .HRESETn(hresetn),
        .manager_ports(manager_ports),
        .subordinate_ports(subordinate_ports)
    );

    // =========================================================================
    // Subordinate 0: Boot ROM
    // =========================================================================
    bus_protocol_if rom_generic_if();
    
    ahb_subordinate #(
        .BASE_ADDR(BOOT_ROM_BASE),
        .NUM_WORDS(BOOT_ROM_WORDS),
        .HDATA_WIDTH(32)
    ) u_ahb_subord_rom (
        .HCLK(hclk),
        .HRESETn(hresetn),
        .ahb(subordinate_ports[0]),
        .generic_if(rom_generic_if.protocol)
    );

    ff_ram #(
        .NBYTES(BOOT_ROM_WORDS * 4),
        .ROM(1),
        .LATENCY(0),
        .INIT_FILE("meminit.bin") // Will be overridden or ignored for now
    ) u_boot_rom (
        .clk(hclk),
        .rst_n(hresetn),
        .bus(rom_generic_if.peripheral_vital)
    );

    // =========================================================================
    // Subordinate 1: On-Chip RAM
    // =========================================================================
    bus_protocol_if ram_generic_if();
    
    ahb_subordinate #(
        .BASE_ADDR(ON_CHIP_RAM_BASE),
        .NUM_WORDS(ON_CHIP_RAM_WORDS),
        .HDATA_WIDTH(32)
    ) u_ahb_subord_ram (
        .HCLK(hclk),
        .HRESETn(hresetn),
        .ahb(subordinate_ports[1]),
        .generic_if(ram_generic_if.protocol)
    );

    ff_ram #(
        .NBYTES(ON_CHIP_RAM_WORDS * 4),
        .ROM(0),
        .LATENCY(0)
    ) u_on_chip_ram (
        .clk(hclk),
        .rst_n(hresetn),
        .bus(ram_generic_if.peripheral_vital)
    );

    // =========================================================================
    // Subordinate 2: Off-Chip SRAM Controller
    // =========================================================================
    bus_protocol_if sram_generic_if();
    
    ahb_subordinate #(
        .BASE_ADDR(OFF_CHIP_SRAM_BASE),
        .NUM_WORDS(OFF_CHIP_SRAM_WORDS),
        .HDATA_WIDTH(32)
    ) u_ahb_subord_sram (
        .HCLK(hclk),
        .HRESETn(hresetn),
        .ahb(subordinate_ports[2]),
        .generic_if(sram_generic_if.protocol)
    );

    sram_if sram_ctrl_if();

    sram_controller #(
        .ADDR_WIDTH(19),
        .WAIT_CYCLES(2)
    ) u_sram_controller (
        .HCLK(hclk),
        .nRST(hresetn),
        .bus(sram_generic_if.peripheral_vital),
        .sram(sram_ctrl_if.controller)
    );

    // Connect to top-level pins
    assign intf.sram_addr   = sram_ctrl_if.addr;
    assign intf.sram_wdata  = sram_ctrl_if.wdata;
    assign sram_ctrl_if.rdata = intf.sram_rdata;
    assign intf.sram_pad_oe = sram_ctrl_if.pad_oe;
    assign intf.sram_ce0_n  = sram_ctrl_if.ce0_n;
    assign intf.sram_oe0_n  = sram_ctrl_if.oe0_n;
    assign intf.sram_we0_n  = sram_ctrl_if.we0_n;
    assign intf.sram_ub0_n  = sram_ctrl_if.ub0_n;
    assign intf.sram_lb0_n  = sram_ctrl_if.lb0_n;
    assign intf.sram_ce1_n  = sram_ctrl_if.ce1_n;
    assign intf.sram_oe1_n  = sram_ctrl_if.oe1_n;
    assign intf.sram_we1_n  = sram_ctrl_if.we1_n;
    assign intf.sram_ub1_n  = sram_ctrl_if.ub1_n;
    assign intf.sram_lb1_n  = sram_ctrl_if.lb1_n;

    // =========================================================================
    // Subordinate 3: APB Bridge & Interconnect
    // =========================================================================
    apb_if apb_bridge_if(.PCLK(pclk), .PRESETn(presetn));

    ahb2apb #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .BASE_ADDR(APB_BRIDGE_BASE),
        .FIFO_DEPTH(16),
        .NWORDS(APB_BRIDGE_WORDS)
    ) u_ahb2apb (
        .ahbif(subordinate_ports[3]),
        .apbif(apb_bridge_if)
    );

    // APB Interconnect (Empty for S3, will decode errors for out-of-bounds APB access)
    localparam int NCOMPLETERS = 1;
    localparam logic [31:0] APB_MAP [NCOMPLETERS] = '{ 32'hFFFF_FFFF }; // Unreachable
    localparam logic [31:0] APB_MAP_MASK [NCOMPLETERS] = '{ 32'h0000_0000 };
    
    apb_if dummy_completer_if[NCOMPLETERS](.PCLK(pclk), .PRESETn(presetn));

    apb_interconnect #(
        .NCOMPLETERS(NCOMPLETERS),
        .COMPLETER_ADDR_BITS(16),
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .BUS_REGION_BEGIN(APB_BRIDGE_BASE),
        .APB_MAP(APB_MAP),
        .APB_MAP_MASK(APB_MAP_MASK)
    ) u_apb_interconnect (
        .requester(apb_bridge_if),
        .completers(dummy_completer_if)
    );

    // Tie off dummy completer
    assign dummy_completer_if[0].PRDATA  = '0;
    assign dummy_completer_if[0].PREADY  = 1'b1;
    assign dummy_completer_if[0].PSLVERR = 1'b0;

endmodule
