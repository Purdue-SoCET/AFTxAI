`ifndef __SRAM_IF_SV__
`define __SRAM_IF_SV__

interface sram_if #(
    parameter int ADDR_WIDTH = 19
);
    logic [ADDR_WIDTH-1:0] addr;
    logic [15:0] wdata;
    logic [15:0] rdata;
    logic pad_oe;

    // Control signals for Chip 0 (lower 16 bits)
    logic ce0_n;
    logic oe0_n;
    logic we0_n;
    logic ub0_n;
    logic lb0_n;

    // Control signals for Chip 1 (upper 16 bits)
    logic ce1_n;
    logic oe1_n;
    logic we1_n;
    logic ub1_n;
    logic lb1_n;

    modport controller (
        output addr, wdata, pad_oe,
               ce0_n, oe0_n, we0_n, ub0_n, lb0_n,
               ce1_n, oe1_n, we1_n, ub1_n, lb1_n,
        input  rdata
    );

    modport sram (
        input  addr, wdata, pad_oe,
               ce0_n, oe0_n, we0_n, ub0_n, lb0_n,
               ce1_n, oe1_n, we1_n, ub1_n, lb1_n,
        output rdata
    );

endinterface

`endif
