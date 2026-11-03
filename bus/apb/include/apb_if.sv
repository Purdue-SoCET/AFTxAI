`ifndef APB_IF_SV
`define APB_IF_SV

interface apb_if #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
) (
    input logic pclk,
    input logic presetn
);
    logic [ADDR_WIDTH-1:0]     PADDR;
    logic                      PSEL;
    logic                      PENABLE;
    logic                      PWRITE;
    logic [DATA_WIDTH-1:0]     PWDATA;
    logic [(DATA_WIDTH/8)-1:0] PSTRB;
    logic [2:0]                PPROT;
    logic [DATA_WIDTH-1:0]     PRDATA;
    logic                      PREADY;
    logic                      PSLVERR;

    modport requester (
        output PADDR, PSEL, PENABLE, PWRITE, PWDATA, PSTRB, PPROT,
        input  PRDATA, PREADY, PSLVERR
    );

    modport completer (
        input  PADDR, PSEL, PENABLE, PWRITE, PWDATA, PSTRB, PPROT,
        output PRDATA, PREADY, PSLVERR
    );
endinterface

`endif // APB_IF_SV
