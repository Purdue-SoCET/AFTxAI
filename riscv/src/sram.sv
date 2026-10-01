`timescale 1ns/1ps

module sram #(
  parameter RAM_SIZE = 16384, // 16KB default
  parameter INIT_FILE = ""
)(
  input  logic clk,
  
  input  logic [31:0] req_addr,
  input  logic [31:0] req_data,
  input  logic [3:0]  req_be,
  input  logic        req_write,
  input  logic        req_valid,
  output logic        req_ready,
  
  output logic [31:0] resp_data,
  output logic        resp_valid
);

  logic [31:0] mem [0:(RAM_SIZE/4)-1];
  
  initial begin
    if (INIT_FILE != "") begin
      $readmemh(INIT_FILE, mem);
    end
  end

  logic [$clog2(RAM_SIZE/4)-1:0] addr_idx;
  assign addr_idx = req_addr[$clog2(RAM_SIZE/4)+1:2];

  assign req_ready = 1'b1; // Always ready

  always_ff @(posedge clk) begin
    resp_valid <= 1'b0;
    if (req_valid) begin
      if (req_write) begin
        if (req_be[0]) mem[addr_idx][7:0]   <= req_data[7:0];
        if (req_be[1]) mem[addr_idx][15:8]  <= req_data[15:8];
        if (req_be[2]) mem[addr_idx][23:16] <= req_data[23:16];
        if (req_be[3]) mem[addr_idx][31:24] <= req_data[31:24];
        resp_valid <= 1'b1; // Acknowledge write
      end else begin
        resp_data  <= mem[addr_idx];
        resp_valid <= 1'b1; // Data is ready next cycle
      end
    end
  end

endmodule