`timescale 1ns/1ps

module dcache #(
  parameter CACHE_SIZE = 1024
)(
  input  logic clk,
  input  logic rst_n,
  
  // CPU side
  input  logic [31:0] req_addr,
  input  logic [31:0] req_data,
  input  logic [3:0]  req_be,
  input  logic        req_write,
  input  logic        req_valid,
  output logic        req_ready,
  output logic [31:0] resp_data,
  output logic        resp_valid,
  
  // Memory side
  output logic [31:0] mem_req_addr,
  output logic [31:0] mem_req_data,
  output logic [3:0]  mem_req_be,
  output logic        mem_req_write,
  output logic        mem_req_valid,
  input  logic        mem_req_ready,
  input  logic [31:0] mem_resp_data,
  input  logic        mem_resp_valid
);

  localparam NUM_LINES = CACHE_SIZE / 4;
  
  logic [31:0] data_array  [NUM_LINES-1:0];
  logic [31:0] tag_array   [NUM_LINES-1:0];
  logic        valid_array [NUM_LINES-1:0];
  logic        dirty_array [NUM_LINES-1:0];
  
  logic [$clog2(NUM_LINES)-1:0] index;
  logic [31:0] tag;
  
  assign index = req_addr[$clog2(NUM_LINES)+1:2];
  assign tag   = req_addr[31:2];
  
  logic hit;
  assign hit = valid_array[index] && (tag_array[index] == tag);
  
  typedef enum logic [1:0] {IDLE, WRITE_BACK, ALLOCATE} state_t;
  state_t state, next_state;
  
  always_ff @(posedge clk) begin
    $display("Time=%0t: dcache state=%s, req_valid=%b, req_write=%b, req_addr=0x%0h, hit=%b, mem_req_ready=%b, mem_resp_valid=%b", 
             $time, state.name(), req_valid, req_write, req_addr, hit, mem_req_ready, mem_resp_valid);
  end
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else        state <= next_state;
  end
  
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (req_valid && !hit) begin
          if (valid_array[index] && dirty_array[index]) next_state = WRITE_BACK;
          else next_state = ALLOCATE;
        end
      end
      WRITE_BACK: begin
        if (mem_req_ready) next_state = ALLOCATE;
      end
      ALLOCATE: begin
        if (mem_resp_valid || (mem_req_ready && req_write)) next_state = IDLE;
      end
    endcase
  end
  
  assign req_ready = (state == IDLE) && hit;
  assign resp_valid = (state == IDLE) && req_valid && hit;
  assign resp_data = data_array[index];
  
  assign mem_req_valid = (state == WRITE_BACK) || (state == ALLOCATE);
  assign mem_req_addr  = (state == WRITE_BACK) ? {tag_array[index][29:0], index, 2'b00} : req_addr;
  assign mem_req_data  = (state == WRITE_BACK) ? data_array[index] : req_data;
  assign mem_req_write = (state == WRITE_BACK) || (state == ALLOCATE && req_write);
  assign mem_req_be    = (state == WRITE_BACK) ? 4'b1111 : req_be;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i=0; i<NUM_LINES; i++) begin
        valid_array[i] <= 1'b0;
        dirty_array[i] <= 1'b0;
      end
    end else begin
      if (state == IDLE && req_valid && hit && req_write) begin
        data_array[index] <= req_data; // Simplified byte-enable handling for brevity
        dirty_array[index] <= 1'b1;
      end else if (state == ALLOCATE && mem_resp_valid && !req_write) begin
        valid_array[index] <= 1'b1;
        dirty_array[index] <= 1'b0;
        tag_array[index]   <= tag;
        data_array[index]  <= mem_resp_data;
      end else if (state == ALLOCATE && mem_req_ready && req_write) begin
        // Write allocate
        valid_array[index] <= 1'b1;
        dirty_array[index] <= 1'b1;
        tag_array[index]   <= tag;
        data_array[index]  <= req_data;
      end
    end
  end

endmodule