`ifndef CACHE_BUS_IF_SV
`define CACHE_BUS_IF_SV

interface cache_bus_if;
    logic        req;
    logic        gnt;
    logic [31:0] addr;
    logic        rnw;
    logic [31:0] wdata;
    logic [31:0] rdata;
    logic        valid;
    logic        last;
    logic        error;

    modport cache (
        output req, addr, rnw, wdata,
        input  gnt, rdata, valid, last, error
    );

    modport bus_ctrl (
        input  req, addr, rnw, wdata,
        output gnt, rdata, valid, last, error
    );
endinterface

`endif
