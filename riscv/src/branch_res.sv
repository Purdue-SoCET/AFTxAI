`timescale 1ns/1ps
import riscv_pkg::*;

module branch_res (
  input  logic [31:0]  rs1_data_i,
  input  logic [31:0]  rs2_data_i,
  input  branch_type_t branch_type_i,
  output logic         take_branch_o
);

  always_comb begin
    case (branch_type_i)
      BR_BEQ:  take_branch_o = (rs1_data_i == rs2_data_i);
      BR_BNE:  take_branch_o = (rs1_data_i != rs2_data_i);
      BR_BLT:  take_branch_o = ($signed(rs1_data_i) < $signed(rs2_data_i));
      BR_BGE:  take_branch_o = ($signed(rs1_data_i) >= $signed(rs2_data_i));
      BR_BLTU: take_branch_o = (rs1_data_i < rs2_data_i);
      BR_BGEU: take_branch_o = (rs1_data_i >= rs2_data_i);
      default: take_branch_o = 1'b0;
    endcase
  end

endmodule