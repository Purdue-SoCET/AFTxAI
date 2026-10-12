`ifndef CPU_CACHE_IF_SV
`define CPU_CACHE_IF_SV

interface cpu_cache_if;
    logic        valid;
    logic        ready;
    logic [31:0] addr;
    logic [31:0] wdata;
    logic [3:0]  wstrb;
    logic [31:0] rdata;
    logic        error;

    modport cpu (
        output valid, addr, wdata, wstrb,
        input  ready, rdata, error
    );

    modport cache (
        input  valid, addr, wdata, wstrb,
        output ready, rdata, error
    );
endinterface

`endif
