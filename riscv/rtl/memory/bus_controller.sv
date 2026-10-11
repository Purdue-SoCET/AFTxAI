`timescale 1ns/1ps

module bus_controller (
    input  logic HCLK,
    input  logic nRST,

    // Interface from iCache
    cache_bus_if.bus_ctrl icache_if,

    // Interface from dCache
    cache_bus_if.bus_ctrl dcache_if,

    // Interface to External AHB Manager
    bus_ahbm_if.manager ahbm_if
);

    // Error Halt State
    logic halt_error_q;

    always_ff @(posedge HCLK or negedge nRST) begin
        if (!nRST) begin
            halt_error_q <= 1'b0;
        end else if (ahbm_if.error) begin
            halt_error_q <= 1'b1;
        end
    end

    // TODO: Implement Arbitration (dCache > iCache)
    // TODO: Implement FSM to translate cache_bus_if to bus_ahbm_if
    // TODO: Unbuffered routing to external AHB interface

    always_comb begin
        // Stub assignments
        icache_if.gnt = 1'b0;
        icache_if.rdata = 32'b0;
        icache_if.valid = 1'b0;
        icache_if.last = 1'b0;
        icache_if.error = halt_error_q;

        dcache_if.gnt = 1'b0;
        dcache_if.rdata = 32'b0;
        dcache_if.valid = 1'b0;
        dcache_if.last = 1'b0;
        dcache_if.error = halt_error_q;

        ahbm_if.req = 1'b0;
        ahbm_if.addr = 32'b0;
        ahbm_if.rnw = 1'b0;
        ahbm_if.size = 3'b0;
        ahbm_if.wdata = 32'b0;
    end

endmodule
