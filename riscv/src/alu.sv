`timescale 1ns/1ps
import riscv_pkg::*;

module alu (
  input  logic [31:0] a_i,
  input  logic [31:0] b_i,
  input  alu_op_t     alu_op_i,
  output logic [31:0] result_o
);

  always_comb begin
    case (alu_op_i)
      ALU_ADD:  result_o = a_i + b_i;
      ALU_SUB:  result_o = a_i - b_i;
      ALU_SLL:  result_o = a_i << b_i[4:0];
      ALU_SLT:  result_o = {31'b0, ($signed(a_i) < $signed(b_i))};
      ALU_SLTU: result_o = {31'b0, (a_i < b_i)};
      ALU_XOR:  result_o = a_i ^ b_i;
      ALU_SRL:  result_o = a_i >> b_i[4:0];
      ALU_SRA:  result_o = $signed(a_i) >>> b_i[4:0];
      ALU_OR:   result_o = a_i | b_i;
      ALU_AND:  result_o = a_i & b_i;
      default:  result_o = 32'b0;
    endcase
  end

endmodule