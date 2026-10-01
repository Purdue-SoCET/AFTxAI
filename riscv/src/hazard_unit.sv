`timescale 1ns/1ps

module hazard_unit (
  input  logic       icache_ready_i,
  input  logic       dcache_ready_i,
  input  logic       dcache_valid_req_i,
  input  logic [4:0] if_id_rs1_i,
  input  logic [4:0] if_id_rs2_i,
  input  logic [4:0] id_ex_rd_i,
  input  logic       id_ex_mem_read_i,
  input  logic       branch_taken_i,
  input  logic       jump_i,
  
  output logic       stall_if_o,
  output logic       stall_id_o,
  output logic       stall_ex_o,
  output logic       flush_if_o,
  output logic       flush_id_o
);

  logic load_use_hazard;
  logic cache_stall;

  always_comb begin
    // Load-use hazard detection
    load_use_hazard = id_ex_mem_read_i && 
                      ((id_ex_rd_i == if_id_rs1_i) || (id_ex_rd_i == if_id_rs2_i)) && 
                      (id_ex_rd_i != 5'b0);

    // Cache miss stalls
    cache_stall = !icache_ready_i || (dcache_valid_req_i && !dcache_ready_i);

    $display("Time=%0t: HAZARD: cache_stall=%b, icache_ready=%b, dcache_valid=%b, dcache_ready=%b, load_use=%b",
             $time, cache_stall, icache_ready_i, dcache_valid_req_i, dcache_ready_i, load_use_hazard);

    // Default signals
    stall_if_o = 1'b0;
    stall_id_o = 1'b0;
    stall_ex_o = 1'b0;
    flush_if_o = 1'b0;
    flush_id_o = 1'b0;

    if (cache_stall) begin
      stall_if_o = 1'b1;
      stall_id_o = 1'b1;
      stall_ex_o = 1'b1; // Stall the whole pipeline
    end else if (load_use_hazard) begin
      stall_if_o = 1'b1;
      stall_id_o = 1'b1;
      flush_id_o = 1'b1; // Bubble in EX
    end else if (branch_taken_i || jump_i) begin
      flush_if_o = 1'b1; // Flush IF on control hazard
    end
  end

endmodule