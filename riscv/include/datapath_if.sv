`ifndef DATAPATH_IF_SV
`define DATAPATH_IF_SV
interface datapath_if;
    logic halt; logic icache_valid, icache_ready, icache_error; logic [31:0] icache_addr, icache_rdata; logic dcache_valid, dcache_ready, dcache_error; logic [31:0] dcache_addr, dcache_wdata, dcache_rdata; logic [3:0] dcache_wstrb; modport mp(output halt, icache_valid, icache_addr, dcache_valid, dcache_addr, dcache_wdata, dcache_wstrb, input icache_ready, icache_rdata, icache_error, dcache_ready, dcache_rdata, dcache_error);
endinterface
`endif
