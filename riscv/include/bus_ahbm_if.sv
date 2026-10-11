`ifndef BUS_AHBM_IF_SV
`define BUS_AHBM_IF_SV

interface bus_ahbm_if;
    logic        req;
    logic        ack;
    logic [31:0] addr;
    logic        rnw;
    logic [2:0]  size;
    logic [31:0] wdata;
    logic [31:0] rdata;
    logic        error;

    modport manager (
        output req, addr, rnw, size, wdata,
        input  ack, rdata, error
    );

    modport subordinate (
        input  req, addr, rnw, size, wdata,
        output ack, rdata, error
    );
endinterface

`endif
