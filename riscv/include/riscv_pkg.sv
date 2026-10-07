package riscv_pkg;

  // ISA Base Configuration
  parameter int RV32E = 0; // 0 for RV32I, 1 for RV32E
  parameter int EXT_A = 1; // 1 for Atomics enabled
  parameter int EXT_M = 0; // Stub for M extension
  parameter int EXT_C = 0; // Stub for C extension

  // Memory map constants
  localparam logic [31:0] SRAM_BASE = 32'h0000_0000;
  localparam logic [31:0] SRAM_END  = 32'h0FFF_FFFF;
  localparam logic [31:0] MMIO_BASE = 32'h1000_0000;
  localparam logic [31:0] MMIO_END  = 32'h1FFF_FFFF;
  localparam logic [31:0] CACHE_CTRL_ADDR = 32'h1000_0000;

  // RISC-V Opcodes
  typedef enum logic [6:0] {
    OPC_LOAD     = 7'b0000011,
    OPC_STORE    = 7'b0100011,
    OPC_BRANCH   = 7'b1100011,
    OPC_JALR     = 7'b1100111,
    OPC_JAL      = 7'b1101111,
    OPC_OP_IMM   = 7'b0010011,
    OPC_OP       = 7'b0110011,
    OPC_SYSTEM   = 7'b1110011,
    OPC_AUIPC    = 7'b0010111,
    OPC_LUI      = 7'b0110111,
    OPC_AMO      = 7'b0101111,
    OPC_MISC_MEM = 7'b0001111
  } opcode_t;

  // Unified Execution Operations
  typedef enum logic [4:0] {
    ALU_ADD, ALU_SUB, ALU_SLL, ALU_SLT, ALU_SLTU, ALU_XOR, ALU_SRL, ALU_SRA, ALU_OR, ALU_AND,
    // AMO ops
    AMO_LR, AMO_SC, AMO_SWAP, AMO_ADD, AMO_XOR, AMO_AND, AMO_OR, AMO_MIN, AMO_MAX, AMO_MINU, AMO_MAXU
  } exec_op_t;

  // Common Decoded Instruction Struct
  typedef struct packed {
    logic       valid;
    logic       is_illegal;
    opcode_t    opcode;
    exec_op_t   exec_op;
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [4:0] rd;
    logic [31:0] imm;
    logic       uses_rs1;
    logic       uses_rs2;
    logic       uses_rd;
    logic       is_branch;
    logic       is_jump;
    logic       is_load;
    logic       is_store;
    logic       is_amo;
    logic       is_csr;
  } decoded_instr_t;

  // Cache & Coherence
  typedef enum logic {
    ICACHE = 1'b0,
    DCACHE = 1'b1
  } cache_type_t;

  typedef enum logic [1:0] {
    MESI_I = 2'b00,
    MESI_S = 2'b01,
    MESI_E = 2'b10,
    MESI_M = 2'b11
  } mesi_state_t;

  typedef enum logic [2:0] {
    BUS_RD,
    BUS_RDX,
    BUS_UPGR,
    BUS_WB,
    BUS_FLUSH,
    BUS_NONE
  } bus_cmd_t;

endpackage
