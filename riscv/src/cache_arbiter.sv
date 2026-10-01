`timescale 1ns/1ps

module cache_arbiter (
  input  logic clk,
  input  logic rst_n,
  
  // From iCache
  input  logic [31:0] ic_req_addr,
  input  logic        ic_req_valid,
  output logic        ic_req_ready,
  output logic [31:0] ic_resp_data,
  output logic        ic_resp_valid,
  
  // From dCache
  input  logic [31:0] dc_req_addr,
  input  logic [31:0] dc_req_data,
  input  logic [3:0]  dc_req_be,
  input  logic        dc_req_write,
  input  logic        dc_req_valid,
  output logic        dc_req_ready,
  output logic [31:0] dc_resp_data,
  output logic        dc_resp_valid,
  
  // To Main Memory (SRAM)
  output logic [31:0] mem_req_addr,
  output logic [31:0] mem_req_data,
  output logic [3:0]  mem_req_be,
  output logic        mem_req_write,
  output logic        mem_req_valid,
  input  logic        mem_req_ready,
  input  logic [31:0] mem_resp_data,
  input  logic        mem_resp_valid
);

  // Simple priority arbiter: dCache > iCache
  logic dcache_grant;
  assign dcache_grant = dc_req_valid;
  
  assign mem_req_addr  = dcache_grant ? dc_req_addr  : ic_req_addr;
  assign mem_req_data  = dcache_grant ? dc_req_data  : 32'b0;
  assign mem_req_write = dcache_grant ? dc_req_write : 1'b0;
  assign mem_req_be    = dcache_grant ? dc_req_be    : 4'b1111;
  assign mem_req_valid = dc_req_valid || ic_req_valid;
  
  assign dc_req_ready  = dcache_grant && mem_req_ready;
  assign ic_req_ready  = !dcache_grant && mem_req_ready;
  
  // Routing responses
  // Since SRAM has 1 cycle latency, we need a register to track who requested
  logic resp_to_dcache;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) resp_to_dcache <= 1'b0;
    else if (mem_req_valid && mem_req_ready) resp_to_dcache <= dcache_grant;
  end
  
  assign dc_resp_data  = mem_resp_data;
  assign ic_resp_data  = mem_resp_data;
  
  assign dc_resp_valid = mem_resp_valid && resp_to_dcache;
  assign ic_resp_valid = mem_resp_valid && !resp_to_dcache;

endmodule