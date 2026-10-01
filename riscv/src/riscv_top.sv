`timescale 1ns/1ps

module riscv_top #(
  parameter bit RV32E = 0,
  parameter logic [31:0] BOOT_ADDR = 32'h0000_0000,
  parameter string INIT_FILE = ""
)(
  input  logic clk,
  input  logic rst_n
);

  // iCache to Arbiter
  logic [31:0] ic_req_addr, ic_resp_data;
  logic ic_req_valid, ic_req_ready, ic_resp_valid;

  // dCache to Arbiter
  logic [31:0] dc_req_addr, dc_req_data, dc_resp_data;
  logic [3:0]  dc_req_be;
  logic dc_req_write, dc_req_valid, dc_req_ready, dc_resp_valid;

  // Arbiter to SRAM
  logic [31:0] mem_req_addr, mem_req_data, mem_resp_data;
  logic [3:0]  mem_req_be;
  logic mem_req_write, mem_req_valid, mem_req_ready, mem_resp_valid;

  // CPU to Caches
  logic [31:0] cpu_ic_req_addr, cpu_ic_resp_data;
  logic cpu_ic_req_valid, cpu_ic_req_ready, cpu_ic_resp_valid;

  logic [31:0] cpu_dc_req_addr, cpu_dc_req_data, cpu_dc_resp_data;
  logic [3:0]  cpu_dc_req_be;
  logic cpu_dc_req_write, cpu_dc_req_valid, cpu_dc_req_ready, cpu_dc_resp_valid;

  datapath #(
    .RV32E(RV32E),
    .BOOT_ADDR(BOOT_ADDR)
  ) core_inst (
    .clk(clk),
    .rst_n(rst_n),
    .icache_req_addr(cpu_ic_req_addr),
    .icache_req_valid(cpu_ic_req_valid),
    .icache_req_ready(cpu_ic_req_ready),
    .icache_resp_data(cpu_ic_resp_data),
    .icache_resp_valid(cpu_ic_resp_valid),
    .dcache_req_addr(cpu_dc_req_addr),
    .dcache_req_data(cpu_dc_req_data),
    .dcache_req_be(cpu_dc_req_be),
    .dcache_req_write(cpu_dc_req_write),
    .dcache_req_valid(cpu_dc_req_valid),
    .dcache_req_ready(cpu_dc_req_ready),
    .dcache_resp_data(cpu_dc_resp_data),
    .dcache_resp_valid(cpu_dc_resp_valid)
  );

  icache icache_inst (
    .clk(clk),
    .rst_n(rst_n),
    .req_addr(cpu_ic_req_addr),
    .req_valid(cpu_ic_req_valid),
    .req_ready(cpu_ic_req_ready),
    .resp_data(cpu_ic_resp_data),
    .resp_valid(cpu_ic_resp_valid),
    .mem_req_addr(ic_req_addr),
    .mem_req_valid(ic_req_valid),
    .mem_req_ready(ic_req_ready),
    .mem_resp_data(ic_resp_data),
    .mem_resp_valid(ic_resp_valid)
  );

  dcache dcache_inst (
    .clk(clk),
    .rst_n(rst_n),
    .req_addr(cpu_dc_req_addr),
    .req_data(cpu_dc_req_data),
    .req_be(cpu_dc_req_be),
    .req_write(cpu_dc_req_write),
    .req_valid(cpu_dc_req_valid),
    .req_ready(cpu_dc_req_ready),
    .resp_data(cpu_dc_resp_data),
    .resp_valid(cpu_dc_resp_valid),
    .mem_req_addr(dc_req_addr),
    .mem_req_data(dc_req_data),
    .mem_req_be(dc_req_be),
    .mem_req_write(dc_req_write),
    .mem_req_valid(dc_req_valid),
    .mem_req_ready(dc_req_ready),
    .mem_resp_data(dc_resp_data),
    .mem_resp_valid(dc_resp_valid)
  );

  cache_arbiter arb_inst (
    .clk(clk),
    .rst_n(rst_n),
    .ic_req_addr(ic_req_addr),
    .ic_req_valid(ic_req_valid),
    .ic_req_ready(ic_req_ready),
    .ic_resp_data(ic_resp_data),
    .ic_resp_valid(ic_resp_valid),
    .dc_req_addr(dc_req_addr),
    .dc_req_data(dc_req_data),
    .dc_req_be(dc_req_be),
    .dc_req_write(dc_req_write),
    .dc_req_valid(dc_req_valid),
    .dc_req_ready(dc_req_ready),
    .dc_resp_data(dc_resp_data),
    .dc_resp_valid(dc_resp_valid),
    .mem_req_addr(mem_req_addr),
    .mem_req_data(mem_req_data),
    .mem_req_be(mem_req_be),
    .mem_req_write(mem_req_write),
    .mem_req_valid(mem_req_valid),
    .mem_req_ready(mem_req_ready),
    .mem_resp_data(mem_resp_data),
    .mem_resp_valid(mem_resp_valid)
  );

  sram #(
    .INIT_FILE(INIT_FILE)
  ) sram_inst (
    .clk(clk),
    .req_addr(mem_req_addr),
    .req_data(mem_req_data),
    .req_be(mem_req_be),
    .req_write(mem_req_write),
    .req_valid(mem_req_valid),
    .req_ready(mem_req_ready),
    .resp_data(mem_resp_data),
    .resp_valid(mem_resp_valid)
  );

endmodule