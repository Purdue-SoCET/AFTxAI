`timescale 1ns/1ps
module riscv #(parameter int RV32E = 0, parameter logic [31:0] BOOT_ADDR = 32'h0000_0000) (
    input logic HCLK, input logic nRST,
    bus_ahbm_if.manager ahbm_if,
    riscv_if.mp port_unused
);
    cpu_cache_if icache_cpu_if();
    cpu_cache_if dcache_cpu_if();
    cache_bus_if icache_bus_if();
    cache_bus_if dcache_bus_if();
    datapath_if dp_if();

    assign dp_if.icache_ready = icache_cpu_if.ready;
    assign dp_if.icache_rdata = icache_cpu_if.rdata;
    assign dp_if.icache_error = icache_cpu_if.error;
    assign dp_if.dcache_ready = dcache_cpu_if.ready;
    assign dp_if.dcache_rdata = dcache_cpu_if.rdata;
    assign dp_if.dcache_error = dcache_cpu_if.error;
    
    datapath #(.RV32E(RV32E), .BOOT_ADDR(BOOT_ADDR)) dp_inst (.HCLK(HCLK), .nRST(nRST), .port(dp_if.mp));

    assign icache_cpu_if.valid = dp_if.icache_valid;
    assign icache_cpu_if.addr = dp_if.icache_addr;
    assign icache_cpu_if.wdata = 32'b0;
    assign icache_cpu_if.wstrb = 4'b0;

    assign dcache_cpu_if.valid = dp_if.dcache_valid;
    assign dcache_cpu_if.addr = dp_if.dcache_addr;
    assign dcache_cpu_if.wdata = dp_if.dcache_wdata;
    assign dcache_cpu_if.wstrb = dp_if.dcache_wstrb;

    l1_cache_if c_if();
    l1_cache #(.CACHE_TYPE(0)) icache_inst (.HCLK(HCLK), .nRST(nRST), .cpu_if(icache_cpu_if), .bus_if(icache_bus_if), .port_unused(c_if.mp));
    l1_cache #(.CACHE_TYPE(1)) dcache_inst (.HCLK(HCLK), .nRST(nRST), .cpu_if(dcache_cpu_if), .bus_if(dcache_bus_if), .port_unused(c_if.mp));
    
    bus_controller_if bc_if();
    bus_controller bus_ctrl_inst (.HCLK(HCLK), .nRST(nRST), .icache_if(icache_bus_if), .dcache_if(dcache_bus_if), .ahbm_if(ahbm_if), .port_unused(bc_if.mp));
endmodule
