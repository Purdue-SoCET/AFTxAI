`timescale 1ns/1ps

module imm_gen (
  input  logic [31:0] instr_i,
  output logic [31:0] imm_o
);

  logic [6:0] opcode;
  assign opcode = instr_i[6:0];

  always_comb begin
    case (opcode)
      // I-type (Loads, ALUI, JALR)
      7'b0000011, 7'b0010011, 7'b1100111: 
        imm_o = {{20{instr_i[31]}}, instr_i[31:20]};
        
      // S-type (Stores)
      7'b0100011: 
        imm_o = {{20{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};
        
      // B-type (Branches)
      7'b1100011: 
        imm_o = {{20{instr_i[31]}}, instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0};
        
      // U-type (LUI, AUIPC)
      7'b0110111, 7'b0010111: 
        imm_o = {instr_i[31:12], 12'b0};
        
      // J-type (JAL)
      7'b1101111: 
        imm_o = {{12{instr_i[31]}}, instr_i[19:12], instr_i[20], instr_i[30:21], 1'b0};
        
      // CSR (Z-imm)
      7'b1110011:
        imm_o = {27'b0, instr_i[19:15]};
        
      default: 
        imm_o = 32'b0;
    endcase
  end

endmodule