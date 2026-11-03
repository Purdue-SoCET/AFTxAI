`ifndef UART_IF_SV
`define UART_IF_SV

interface uart_if #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32
) (
    input logic clk,
    input logic rst_n
);
    // Generic Bus Interface (similar to APB)
    logic                  psel;
    logic                  penable;
    logic                  pwrite;
    logic [ADDR_WIDTH-1:0] paddr;
    logic [DATA_WIDTH-1:0] pwdata;
    logic [DATA_WIDTH-1:0] prdata;
    logic                  pready;
    logic                  pslverr;

    // Serial lines
    logic rx;
    logic tx;
    logic cts_n;
    logic rts_n;

    // Interrupt
    logic irq;

    modport target (
        input  psel, penable, pwrite, paddr, pwdata,
        output prdata, pready, pslverr,
        input  rx, cts_n,
        output tx, rts_n,
        output irq
    );

    modport initiator (
        output psel, penable, pwrite, paddr, pwdata,
        input  prdata, pready, pslverr,
        output rx, cts_n,
        input  tx, rts_n, irq
    );
endinterface

`endif
