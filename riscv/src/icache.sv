`timescale 1ns/1ps

module icache #(
  parameter CACHE_SIZE = 1024,
  parameter LINE_SIZE  = 4
)(
  input  logic clk,
  input  logic rst_n,
  
  // CPU side
  input  logic [31:0] req_addr,
  input  logic        req_valid,
  output logic        req_ready,
  output logic [31:0] resp_data,
  output logic        resp_valid,
  
  // Memory side
  output logic [31:0] mem_req_addr,
  output logic        mem_req_valid,
  input  logic        mem_req_ready,
  input  logic [31:0] mem_resp_data,
  input  logic        mem_resp_valid
);

  // Simplified Direct-Mapped Read-Only Cache (1-word blocks)
  localparam NUM_LINES = CACHE_SIZE / 4;
  
  logic [31:0] data_array [NUM_LINES-1:0];
  logic [31:0] tag_array  [NUM_LINES-1:0];
  logic        valid_array [NUM_LINES-1:0];
  
  logic [$clog2(NUM_LINES)-1:0] index;
  logic [31:0] tag;
  
  assign index = req_addr[$clog2(NUM_LINES)+1:2];
  assign tag   = req_addr[31:2];
  
  logic hit;
  assign hit = valid_array[index] && (tag_array[index] == tag);
  
  assign req_ready = hit || (mem_resp_valid);
  assign resp_valid = req_valid && (hit || mem_resp_valid);
  assign resp_data = hit ? data_array[index] : mem_resp_data;
  
  assign mem_req_addr = req_addr;
  assign mem_req_valid = req_valid && !hit;
  
  always_ff @(posedge clk) begin
    $display("Time=%0t: icache req_valid=%b, req_ready=%b, req_addr=0x%0h, hit=%b, mem_req_valid=%b, mem_resp_valid=%b", 
             $time, req_valid, req_ready, req_addr, hit, mem_req_valid, mem_resp_valid);
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i=0; i<NUM_LINES; i++) valid_array[i] <= 1'b0;
    end else begin
      if (mem_resp_valid && mem_req_valid) begin
        valid_array[index] <= 1'b1;
        tag_array[index]   <= tag;
        data_array[index]  <= mem_resp_data;
      end
    end
  end

endmodule