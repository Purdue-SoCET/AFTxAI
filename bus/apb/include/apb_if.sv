`ifndef __APB_IF_SV__
`define __APB_IF_SV__

interface apb_if #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
)(
    input logic PCLK,
    input logic PRESETn
);

    logic [ADDR_WIDTH-1:0]     PADDR;
    logic [2:0]                PPROT;
    logic                      PSEL;
    logic                      PENABLE;
    logic                      PWRITE;
    logic [DATA_WIDTH-1:0]     PWDATA;
    logic [(DATA_WIDTH/8)-1:0] PSTRB;
    logic                      PREADY;
    logic [DATA_WIDTH-1:0]     PRDATA;
    logic                      PSLVERR;

    modport requester (
        input  PCLK, PRESETn, PREADY, PRDATA, PSLVERR,
        output PADDR, PPROT, PSEL, PENABLE, PWRITE, PWDATA, PSTRB
    );

    modport completer (
        input  PCLK, PRESETn, PADDR, PPROT, PSEL, PENABLE, PWRITE, PWDATA, PSTRB,
        output PREADY, PRDATA, PSLVERR
    );

endinterface

`endif
