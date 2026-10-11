`timescale 1ns/1ps

module core #(
    parameter int RV32E = 0,
    parameter logic [31:0] BOOT_ADDR = 32'h0000_0000
) (
    input  logic HCLK,
    input  logic nRST,

    // Instruction Cache Interface
    cpu_cache_if.cpu icache_if,

    // Data Cache Interface
    cpu_cache_if.cpu dcache_if
);

    datapath #(
        .RV32E(RV32E),
        .BOOT_ADDR(BOOT_ADDR)
    ) dp_inst (
        .HCLK(HCLK),
        .nRST(nRST),
        
        .icache_valid(icache_if.valid),
        .icache_ready(icache_if.ready),
        .icache_addr(icache_if.addr),
        .icache_rdata(icache_if.rdata),
        .icache_error(icache_if.error),
        
        .dcache_valid(dcache_if.valid),
        .dcache_ready(dcache_if.ready),
        .dcache_addr(dcache_if.addr),
        .dcache_wdata(dcache_if.wdata),
        .dcache_wstrb(dcache_if.wstrb),
        .dcache_rdata(dcache_if.rdata),
        .dcache_error(dcache_if.error)
    );

    // Hardwire write interface off for iCache since it's read-only
    assign icache_if.wdata = 32'b0;
    assign icache_if.wstrb = 4'b0;

endmodule
