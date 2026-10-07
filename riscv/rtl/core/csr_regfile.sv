module csr_regfile #(
  parameter int HART_ID = 0,
  parameter int EXT_A = 1
)(
  input  logic        clk,
  input  logic        rst_n,

  // ID/EX Read/Write Interface
  input  logic        csr_we,
  input  logic [11:0] csr_addr,
  input  logic [31:0] csr_wdata,
  input  logic [2:0]  csr_op, // From funct3
  output logic [31:0] csr_rdata,

  // Trap Interface
  input  logic        trap_valid,
  input  logic [31:0] trap_pc,
  input  logic [31:0] trap_cause,
  input  logic [31:0] trap_tval,
  input  logic        mret_valid,

  // Trap/MRET outputs
  output logic [31:0] trap_target,
  output logic [31:0] mret_target
);

  // CSR Register State
  logic [31:0] mstatus, mtvec, mepc, mcause, mtval;
  logic [63:0] mcycle, minstret;

  // Fixed CSRs
  logic [31:0] mhartid = HART_ID;
  // misa: RV32 (base = 1 << 30) | I (bit 8) or E (bit 4) | A (bit 0 if EXT_A)
  // Assuming RV32I for the base here, E config would adjust it
  logic [31:0] misa = (2'b01 << 30) | (1 << 8) | (EXT_A ? 1 : 0);

  // Output Combinational Reads
  always_comb begin
    csr_rdata = 32'd0;
    case (csr_addr)
      12'h300: csr_rdata = mstatus;
      12'h301: csr_rdata = misa;
      12'h305: csr_rdata = mtvec;
      12'h341: csr_rdata = mepc;
      12'h342: csr_rdata = mcause;
      12'h343: csr_rdata = mtval;
      12'hF14: csr_rdata = mhartid;
      12'hB00: csr_rdata = mcycle[31:0];
      12'hB80: csr_rdata = mcycle[63:32];
      12'hB02: csr_rdata = minstret[31:0];
      12'hB82: csr_rdata = minstret[63:32];
      default: csr_rdata = 32'd0;
    endcase
  end

  // Synchronous Writes & Traps
  logic [31:0] next_csr_val;
  always_comb begin
    next_csr_val = csr_rdata;
    case (csr_op)
      3'b001, 3'b101: next_csr_val = csr_wdata;                  // CSRRW, CSRRWI
      3'b010, 3'b110: next_csr_val = csr_rdata | csr_wdata;      // CSRRS, CSRRSI
      3'b011, 3'b111: next_csr_val = csr_rdata & ~csr_wdata;     // CSRRC, CSRRCI
      default:        next_csr_val = csr_rdata;
    endcase
  end

  assign trap_target = mtvec;
  assign mret_target = mepc;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mstatus <= 32'd0;
      mtvec   <= 32'd0;
      mepc    <= 32'd0;
      mcause  <= 32'd0;
      mtval   <= 32'd0;
      mcycle  <= 64'd0;
      minstret<= 64'd0;
    end else begin
      mcycle <= mcycle + 1;
      
      // Instruction retired counting logic would go here
      // For now, simplify and just tick on non-trap cycles
      
      if (trap_valid) begin
        // Push state to Machine mode
        mstatus[7] <= mstatus[3]; // MPIE = MIE
        mstatus[3] <= 1'b0;       // MIE = 0
        mepc       <= trap_pc;
        mcause     <= trap_cause;
        mtval      <= trap_tval;
      end else if (mret_valid) begin
        // Pop state from Machine mode
        mstatus[3] <= mstatus[7]; // MIE = MPIE
        mstatus[7] <= 1'b1;       // MPIE = 1
      end else if (csr_we) begin
        // CSR Instruction Writes
        case (csr_addr)
          12'h300: mstatus <= next_csr_val;
          12'h305: mtvec   <= next_csr_val;
          12'h341: mepc    <= next_csr_val;
          12'h342: mcause  <= next_csr_val;
          12'h343: mtval   <= next_csr_val;
        endcase
      end
    end
  end

endmodule
