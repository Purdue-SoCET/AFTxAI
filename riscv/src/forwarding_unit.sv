`timescale 1ns/1ps

module forwarding_unit (
  input  logic [4:0] id_ex_rs1_i,
  input  logic [4:0] id_ex_rs2_i,
  input  logic [4:0] ex_mem_rd_i,
  input  logic       ex_mem_reg_write_i,
  
  output logic       forward_a_o,
  output logic       forward_b_o
);

  always_comb begin
    forward_a_o = 1'b0;
    forward_b_o = 1'b0;

    // EX/MEM hazard (Forward from MEM stage)
    if (ex_mem_reg_write_i && (ex_mem_rd_i != 5'b0)) begin
      if (ex_mem_rd_i == id_ex_rs1_i) forward_a_o = 1'b1;
      if (ex_mem_rd_i == id_ex_rs2_i) forward_b_o = 1'b1;
    end
  end

endmodule