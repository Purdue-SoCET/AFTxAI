`ifndef CPU_BUS_IF_SV
`define CPU_BUS_IF_SV

// Interface between CPU Pipeline and L1 Caches (iCache / dCache)
interface cpu_cache_if(input logic clk, input logic rst_n);
  logic [31:0] req_addr;
  logic [31:0] req_data; // Used only for dCache writes
  logic [3:0]  req_be;   // Byte enables for store instructions
  logic        req_write;
  logic        req_valid;
  logic        req_ready;
  
  logic [31:0] resp_data;
  logic        resp_valid;

  // CPU perspective
  modport cpu (
    output req_addr, req_data, req_be, req_write, req_valid,
    input  req_ready, resp_data, resp_valid
  );

  // Cache perspective
  modport cache (
    input  req_addr, req_data, req_be, req_write, req_valid,
    output req_ready, resp_data, resp_valid
  );
endinterface

`endif