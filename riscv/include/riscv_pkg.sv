package riscv_pkg;

  // --------------------------------------------------------
  // RISC-V Base Instruction Opcodes (opcode[6:0])
  // --------------------------------------------------------
  typedef enum logic [6:0] {
    OP_LOAD   = 7'b0000011,
    OP_STORE  = 7'b0100011,
    OP_BRANCH = 7'b1100011,
    OP_JALR   = 7'b1100111,
    OP_JAL    = 7'b1101111,
    OP_OP_IMM = 7'b0010011, // ALUI
    OP_OP     = 7'b0110011, // ALUR
    OP_AUIPC  = 7'b0010111,
    OP_LUI    = 7'b0110111,
    OP_SYSTEM = 7'b1110011  // CSR, ECALL, EBREAK
  } opcode_t;

  // --------------------------------------------------------
  // ALU Operations
  // --------------------------------------------------------
  typedef enum logic [3:0] {
    ALU_ADD  = 4'b0000,
    ALU_SUB  = 4'b1000,
    ALU_SLL  = 4'b0001,
    ALU_SLT  = 4'b0010,
    ALU_SLTU = 4'b0011,
    ALU_XOR  = 4'b0100,
    ALU_SRL  = 4'b0101,
    ALU_SRA  = 4'b1101,
    ALU_OR   = 4'b0110,
    ALU_AND  = 4'b0111
  } alu_op_t;

  // --------------------------------------------------------
  // Branch Types
  // --------------------------------------------------------
  typedef enum logic [2:0] {
    BR_BEQ  = 3'b000,
    BR_BNE  = 3'b001,
    BR_BLT  = 3'b100,
    BR_BGE  = 3'b101,
    BR_BLTU = 3'b110,
    BR_BGEU = 3'b111
  } branch_type_t;

endpackage : riscv_pkg