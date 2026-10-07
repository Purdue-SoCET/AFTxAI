typedef enum {R_TYPE, I_TYPE, S_TYPE, B_TYPE, U_TYPE, J_TYPE} instr_format_e;

class riscv_instr_item extends uvm_sequence_item;
  rand instr_format_e format;
  rand bit [6:0] opcode;
  rand bit [4:0] rd;
  rand bit [2:0] funct3;
  rand bit [4:0] rs1;
  rand bit [4:0] rs2;
  rand bit [6:0] funct7;
  rand bit [31:0] imm;

  bit [31:0] instr_bits;

  `uvm_object_utils(riscv_instr_item)

  constraint c_opcode {
    (format == R_TYPE) -> opcode inside {7'b0110011};
    (format == I_TYPE) -> opcode inside {7'b0010011, 7'b0000011, 7'b1100111};
    (format == S_TYPE) -> opcode inside {7'b0100011};
    (format == B_TYPE) -> opcode inside {7'b1100011};
    (format == U_TYPE) -> opcode inside {7'b0110111, 7'b0010111};
    (format == J_TYPE) -> opcode inside {7'b1101111};
  }

  function new(string name = "riscv_instr_item");
    super.new(name);
  endfunction

  function void post_randomize();
    case(format)
      R_TYPE: instr_bits = {funct7, rs2, rs1, funct3, rd, opcode};
      I_TYPE: instr_bits = {imm[11:0], rs1, funct3, rd, opcode};
      S_TYPE: instr_bits = {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode};
      B_TYPE: instr_bits = {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], opcode};
      U_TYPE: instr_bits = {imm[31:12], rd, opcode};
      J_TYPE: instr_bits = {imm[20], imm[10:1], imm[11], imm[19:12], rd, opcode};
    endcase
  endfunction

  virtual function string convert2string();
    return $sformatf("Format: %s, Opcode: 7'b%07b, Instr Bits: 32'h%08x", format.name(), opcode, instr_bits);
  endfunction
endclass