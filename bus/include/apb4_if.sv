`ifndef APB4_IF_SV
`define APB4_IF_SV

interface apb4_if #(
    parameter int ADDR_WIDTH = 8,
    parameter int DATA_WIDTH = 32
) (
    input logic pclk,
    input logic presetn
);

    logic [ADDR_WIDTH-1:0]   paddr;
    logic                    psel;
    logic                    penable;
    logic                    pwrite;
    logic [DATA_WIDTH-1:0]   pwdata;
    logic [(DATA_WIDTH/8)-1:0] pstrb;
    logic [2:0]              pprot;
    logic [DATA_WIDTH-1:0]   prdata;
    logic                    pready;
    logic                    pslverr;

    modport requester (
        output paddr, psel, penable, pwrite, pwdata, pstrb, pprot,
        input  prdata, pready, pslverr
    );

    modport completer (
        input  paddr, psel, penable, pwrite, pwdata, pstrb, pprot,
        output prdata, pready, pslverr
    );

endinterface

`endif
