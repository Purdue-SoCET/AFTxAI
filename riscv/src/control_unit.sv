`timescale 1ns/1ps
import riscv_pkg::*;

module control_unit (
  input  logic [31:0] instr_i,
  output alu_op_t     alu_op_o,
  output logic        alu_src_o,    // 0: rs2, 1: imm
  output logic        reg_write_o,
  output logic        mem_write_o,
  output logic        mem_read_o,
  output logic [1:0]  result_src_o, // 00: ALU, 01: Mem, 10: PC+4 (JAL/JALR)
  output logic        branch_o,
  output logic        jump_o,
  output branch_type_t branch_type_o
);

  logic [6:0] opcode;
  logic [2:0] funct3;
  logic [6:0] funct7;

  assign opcode = instr_i[6:0];
  assign funct3 = instr_i[14:12];
  assign funct7 = instr_i[31:25];

  always_comb begin
    // Defaults
    alu_op_o      = ALU_ADD;
    alu_src_o     = 1'b0;
    reg_write_o   = 1'b0;
    mem_write_o   = 1'b0;
    mem_read_o    = 1'b0;
    result_src_o  = 2'b00;
    branch_o      = 1'b0;
    jump_o        = 1'b0;
    branch_type_o = BR_BEQ;

    case (opcode)
      OP_LOAD: begin
        alu_op_o     = ALU_ADD;
        alu_src_o    = 1'b1;
        reg_write_o  = 1'b1;
        mem_read_o   = 1'b1;
        result_src_o = 2'b01;
      end
      OP_STORE: begin
        alu_op_o    = ALU_ADD;
        alu_src_o   = 1'b1;
        mem_write_o = 1'b1;
      end
      OP_BRANCH: begin
        alu_op_o      = ALU_ADD;
        branch_o      = 1'b1;
        branch_type_o = branch_type_t'(funct3);
      end
      OP_JAL: begin
        jump_o       = 1'b1;
        reg_write_o  = 1'b1;
        result_src_o = 2'b10;
      end
      OP_JALR: begin
        jump_o       = 1'b1;
        alu_src_o    = 1'b1;
        reg_write_o  = 1'b1;
        result_src_o = 2'b10;
      end
      OP_OP_IMM: begin
        alu_src_o   = 1'b1;
        reg_write_o = 1'b1;
        case (funct3)
          3'b000: alu_op_o = ALU_ADD;
          3'b010: alu_op_o = ALU_SLT;
          3'b011: alu_op_o = ALU_SLTU;
          3'b100: alu_op_o = ALU_XOR;
          3'b110: alu_op_o = ALU_OR;
          3'b111: alu_op_o = ALU_AND;
          3'b001: alu_op_o = ALU_SLL;
          3'b101: alu_op_o = (funct7[5]) ? ALU_SRA : ALU_SRL;
        endcase
      end
      OP_OP: begin
        reg_write_o = 1'b1;
        case (funct3)
          3'b000: alu_op_o = (funct7[5]) ? ALU_SUB : ALU_ADD;
          3'b010: alu_op_o = ALU_SLT;
          3'b011: alu_op_o = ALU_SLTU;
          3'b100: alu_op_o = ALU_XOR;
          3'b110: alu_op_o = ALU_OR;
          3'b111: alu_op_o = ALU_AND;
          3'b001: alu_op_o = ALU_SLL;
          3'b101: alu_op_o = (funct7[5]) ? ALU_SRA : ALU_SRL;
        endcase
      end
      OP_LUI: begin
        alu_src_o   = 1'b1;
        reg_write_o = 1'b1;
        alu_op_o    = ALU_ADD; // Actually passes Imm directly if RS1=0
      end
      OP_AUIPC: begin
        alu_src_o   = 1'b1;
        reg_write_o = 1'b1;
        alu_op_o    = ALU_ADD;
      end
      default: ; 
    endcase
  end
endmodule