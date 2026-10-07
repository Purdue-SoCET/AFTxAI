import riscv_pkg::*;

module datapath #(
  parameter int HART_ID = 0,
  parameter int RV32E = 0,
  parameter int EXT_A = 1
)(
  input  logic        clk,
  input  logic        rst_n,

  // Cache Interfaces
  cache_if.cpu        icache,
  cache_if.cpu        dcache

`ifdef RISCV_TRACE
  ,
  // RVFI-style Commit Trace Port
  output logic [31:0] trace_pc,
  output logic [31:0] trace_instr,
  output logic [4:0]  trace_rd_addr,
  output logic [31:0] trace_rd_wdata,
  output logic        trace_rd_we,
  output logic [31:0] trace_mem_addr,
  output logic [31:0] trace_mem_wdata,
  output logic [3:0]  trace_mem_wmask,
  output logic        trace_trap
`endif
);

  // --------------------------------------------------------------------------
  // Hazards & Pipeline Control
  // --------------------------------------------------------------------------
  logic stall_if, stall_id, stall_ex, stall_mem;
  logic flush_if, flush_id, flush_ex;
  
  logic load_use_stall, branch_mispredict, trap_flush;
  logic icache_stall, dcache_stall;
  logic mem_is_amo_progress;

  // Forward Declarations
  logic [31:0] idex_pc;
  logic        idex_pred_taken;
  logic [31:0] idex_pred_target;
  logic        idex_valid;
  logic [31:0] idex_instr;
  
  logic [31:0] branch_target, corrected_pc;
  logic [31:0] trap_target;
  
  logic        memwb_is_load;
  logic        memwb_is_amo;
  logic [4:0]  memwb_rd;
  
  decoded_instr_t dec;

  assign icache_stall = icache.req && !icache.valid;
  assign dcache_stall = dcache.req && !dcache.valid;

  hazard_unit u_hazard (
    .id_rs1(idex_instr[19:15]), .id_rs2(idex_instr[24:20]),
    .id_uses_rs1(dec.uses_rs1), .id_uses_rs2(dec.uses_rs2),
    .ex_is_load(memwb_is_load), .ex_is_amo(memwb_is_amo), .ex_rd(memwb_rd),
    .mem_is_amo(mem_is_amo_progress),
    .icache_stall(icache_stall), .dcache_stall(dcache_stall),
    .branch_mispredict(branch_mispredict), .trap_flush(trap_flush),
    .stall_if(stall_if), .stall_id(stall_id), .stall_ex(stall_ex), .stall_mem(stall_mem),
    .flush_if(flush_if), .flush_id(flush_id), .flush_ex(flush_ex)
  );

  // --------------------------------------------------------------------------
  // STAGE: IF (Instruction Fetch)
  // --------------------------------------------------------------------------
  logic [31:0] pc_q, next_pc;
  logic        pred_taken;
  logic [31:0] pred_target;

  // Branch Predictor
  branch_predictor u_bp (
    .clk(clk), .rst_n(rst_n),
    .fetch_pc(pc_q), .pred_taken(pred_taken), .pred_target(pred_target),
    .ex_valid(idex_valid), .ex_pc(idex_pc), 
    .ex_is_branch(dec.is_branch), .ex_is_jump(dec.is_jump),
    .ex_actually_taken(branch_mispredict ? !idex_pred_taken : idex_pred_taken), // Resolved in ID/EX
    .ex_target(branch_target)
  );

  logic [31:0] actual_next_pc;
  assign actual_next_pc = pred_taken ? pred_target : (pc_q + 4);

  always_comb begin
    if (trap_flush)         next_pc = trap_target;
    else if (branch_mispredict) next_pc = corrected_pc;
    else                    next_pc = actual_next_pc;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)             pc_q <= 32'd0; // Reset Vector
    else if (!stall_if)     pc_q <= next_pc;
  end

  assign icache.req  = !flush_if;
  assign icache.addr = pc_q;
  assign icache.we   = 1'b0;
  assign icache.is_amo = 1'b0;

  // IF -> ID/EX Pipeline Register

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush_if) begin
      idex_valid <= 1'b0;
      idex_pc    <= 32'd0;
    end else if (!stall_id) begin
      idex_valid       <= icache.valid;
      idex_pc          <= pc_q;
      idex_pred_taken  <= pred_taken;
      idex_pred_target <= pred_target;
    end
  end

  // --------------------------------------------------------------------------
  // STAGE: ID/EX (Decode / Execute)
  // --------------------------------------------------------------------------
  assign idex_instr = icache.rdata; // Instruction arrives directly into ID/EX

  decoder #(.RV32E(RV32E), .EXT_A(EXT_A)) u_dec (
    .instr(idex_instr), .dec(dec)
  );

  logic [31:0] rs1_data, rs2_data;
  logic [31:0] memwb_rd_wdata;
  logic        memwb_rd_we;

  regfile #(.RV32E(RV32E)) u_regfile (
    .clk(clk), .rst_n(rst_n),
    .rs1_addr(dec.rs1), .rs2_addr(dec.rs2),
    .rd_addr(memwb_rd), .rd_wdata(memwb_rd_wdata), .rd_we(memwb_rd_we),
    .rs1_rdata(rs1_data), .rs2_rdata(rs2_data)
  );

  logic forward_a, forward_b;
  forwarding_unit u_fwd (
    .id_rs1(dec.rs1), .id_rs2(dec.rs2),
    .id_uses_rs1(dec.uses_rs1), .id_uses_rs2(dec.uses_rs2),
    .mem_rd(memwb_rd), .mem_rd_we(memwb_rd_we),
    .forward_a(forward_a), .forward_b(forward_b)
  );

  logic [31:0] alu_in_a, alu_in_b, alu_res;
  assign alu_in_a = forward_a ? memwb_rd_wdata : rs1_data;
  assign alu_in_b = forward_b ? memwb_rd_wdata : rs2_data;

  logic [31:0] true_alu_b;
  always_comb begin
    if (dec.is_branch || dec.opcode == OPC_OP) true_alu_b = alu_in_b;
    else true_alu_b = dec.imm;
  end

  alu u_alu (
    .op(dec.exec_op), .a(alu_in_a), .b(true_alu_b), .res(alu_res)
  );

  // Branch Resolution
  logic branch_taken;

  always_comb begin
    branch_taken = 1'b0;
    case (idex_instr[14:12]) // funct3
      3'b000: branch_taken = (alu_in_a == alu_in_b);                  // BEQ
      3'b001: branch_taken = (alu_in_a != alu_in_b);                  // BNE
      3'b100: branch_taken = ($signed(alu_in_a) < $signed(alu_in_b)); // BLT
      3'b101: branch_taken = ($signed(alu_in_a) >= $signed(alu_in_b));// BGE
      3'b110: branch_taken = (alu_in_a < alu_in_b);                   // BLTU
      3'b111: branch_taken = (alu_in_a >= alu_in_b);                  // BGEU
    endcase

    branch_target = idex_pc + dec.imm;
    
    // Jump specific handling
    if (dec.opcode == OPC_JALR) branch_target = (alu_in_a + dec.imm) & ~32'd1;
    if (dec.is_jump) branch_taken = 1'b1;

    branch_mispredict = 1'b0;
    corrected_pc = 32'd0;

    if (idex_valid && (dec.is_branch || dec.is_jump)) begin
      if (branch_taken != idex_pred_taken || (branch_taken && branch_target != idex_pred_target)) begin
        branch_mispredict = 1'b1;
        corrected_pc = branch_taken ? branch_target : (idex_pc + 4);
      end
    end
  end

  // Store & AMO Data Alignment
  logic [31:0] dcache_wdata;
  logic [3:0]  dcache_wmask;
  always_comb begin
    dcache_wdata = alu_in_b;
    dcache_wmask = 4'b1111;
    if (dec.is_store) begin
      case (idex_instr[14:12])
        3'b000: begin // SB
          dcache_wdata = alu_in_b << (alu_res[1:0] * 8);
          dcache_wmask = 4'b0001 << alu_res[1:0];
        end
        3'b001: begin // SH
          dcache_wdata = alu_in_b << (alu_res[1] * 16);
          dcache_wmask = 4'b0011 << (alu_res[1] * 2);
        end
        default: begin // SW
          dcache_wdata = alu_in_b;
          dcache_wmask = 4'b1111;
        end
      endcase
    end
  end

  // CSR / Trap Logic
  logic [31:0] csr_rdata;
  logic        mret_valid;
  logic [31:0] trap_cause;
  logic [31:0] trap_tval;

  assign mret_valid = (dec.opcode == OPC_SYSTEM && idex_instr[31:20] == 12'h302);
  
  always_comb begin
    trap_flush = 1'b0;
    trap_cause = 32'd0;
    trap_tval  = 32'd0;
    
    if (idex_valid) begin
      if (dec.is_illegal) begin
        trap_flush = 1'b1;
        trap_cause = 32'd2; // Illegal instruction
        trap_tval  = idex_instr;
      end else if (mret_valid) begin
        trap_flush = 1'b1;
      end else if (idex_instr == 32'h00000073) begin // ECALL
        trap_flush = 1'b1;
        trap_cause = 32'd11; // ECALL from M-mode
      end else if (idex_instr == 32'h00100073) begin // EBREAK
        trap_flush = 1'b1;
        trap_cause = 32'd3;  // Breakpoint
      end
    end
  end

  csr_regfile #(.HART_ID(HART_ID), .EXT_A(EXT_A)) u_csr (
    .clk(clk), .rst_n(rst_n),
    .csr_we(dec.is_csr && idex_valid), .csr_addr(idex_instr[31:20]),
    .csr_wdata(alu_in_a), .csr_op(idex_instr[14:12]), .csr_rdata(csr_rdata),
    .trap_valid(trap_flush && !mret_valid), .trap_pc(idex_pc), 
    .trap_cause(trap_cause), .trap_tval(trap_tval), .mret_valid(mret_valid),
    .trap_target(trap_target), .mret_target() // Unused mret_target, next_pc uses trap_target
  );

  // ID/EX -> MEM/WB Pipeline Register
  logic        memwb_valid;
  logic [31:0] memwb_pc;
  logic [31:0] memwb_instr;
  logic [31:0] memwb_alu_res;
  logic [31:0] memwb_wdata;
  logic [3:0]  memwb_wmask;
  logic [2:0]  memwb_funct3;
  logic        memwb_is_store;
  logic        memwb_is_csr;
  logic [31:0] memwb_csr_rdata;
  exec_op_t    memwb_exec_op;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush_id) begin
      memwb_valid    <= 1'b0;
      memwb_is_load  <= 1'b0;
      memwb_is_store <= 1'b0;
      memwb_is_amo   <= 1'b0;
      memwb_rd_we    <= 1'b0;
      memwb_rd       <= 5'd0;
    end else if (!stall_ex) begin
      memwb_valid    <= idex_valid;
      memwb_pc       <= idex_pc;
      memwb_instr    <= idex_instr;
      memwb_alu_res  <= alu_res;
      memwb_wdata    <= dcache_wdata;
      memwb_wmask    <= dcache_wmask;
      memwb_funct3   <= idex_instr[14:12];
      memwb_rd       <= dec.rd;
      memwb_rd_we    <= dec.uses_rd;
      memwb_is_load  <= dec.is_load;
      memwb_is_store <= dec.is_store;
      memwb_is_amo   <= dec.is_amo;
      memwb_is_csr   <= dec.is_csr;
      memwb_csr_rdata<= csr_rdata;
      memwb_exec_op  <= dec.exec_op;
    end
  end

  // --------------------------------------------------------------------------
  // STAGE: MEM/WB (Memory & Writeback)
  // --------------------------------------------------------------------------
  assign dcache.req    = memwb_valid && (memwb_is_load || memwb_is_store || memwb_is_amo);
  assign dcache.addr   = memwb_alu_res;
  assign dcache.wdata  = memwb_wdata;
  assign dcache.wmask  = memwb_wmask;
  assign dcache.we     = memwb_is_store || memwb_is_amo;
  assign dcache.is_amo = memwb_is_amo;
  assign dcache.amo_op = memwb_exec_op;

  assign mem_is_amo_progress = memwb_is_amo && !dcache.valid;

  // Load Data Alignment
  logic [31:0] load_rdata;
  always_comb begin
    load_rdata = dcache.rdata;
    case (memwb_funct3)
      3'b000: begin // LB
        case (memwb_alu_res[1:0])
          2'b00: load_rdata = {{24{dcache.rdata[7]}}, dcache.rdata[7:0]};
          2'b01: load_rdata = {{24{dcache.rdata[15]}}, dcache.rdata[15:8]};
          2'b10: load_rdata = {{24{dcache.rdata[23]}}, dcache.rdata[23:16]};
          2'b11: load_rdata = {{24{dcache.rdata[31]}}, dcache.rdata[31:24]};
        endcase
      end
      3'b001: begin // SH
        if (memwb_alu_res[1]) load_rdata = {{16{dcache.rdata[31]}}, dcache.rdata[31:16]};
        else                  load_rdata = {{16{dcache.rdata[15]}}, dcache.rdata[15:0]};
      end
      3'b100: begin // LBU
        case (memwb_alu_res[1:0])
          2'b00: load_rdata = {24'd0, dcache.rdata[7:0]};
          2'b01: load_rdata = {24'd0, dcache.rdata[15:8]};
          2'b10: load_rdata = {24'd0, dcache.rdata[23:16]};
          2'b11: load_rdata = {24'd0, dcache.rdata[31:24]};
        endcase
      end
      3'b101: begin // LHU
        if (memwb_alu_res[1]) load_rdata = {16'd0, dcache.rdata[31:16]};
        else                  load_rdata = {16'd0, dcache.rdata[15:0]};
      end
      default: load_rdata = dcache.rdata; // LW, AMO
    endcase
  end

  // Writeback Mux
  always_comb begin
    memwb_rd_wdata = memwb_alu_res;
    if (memwb_is_load || memwb_is_amo) memwb_rd_wdata = load_rdata;
    else if (memwb_is_csr)             memwb_rd_wdata = memwb_csr_rdata;
    else if (memwb_instr[6:0] == OPC_JAL || memwb_instr[6:0] == OPC_JALR) memwb_rd_wdata = memwb_pc + 4;
  end

  // RVFI Commit Trace
`ifdef RISCV_TRACE
  assign trace_pc        = memwb_pc;
  assign trace_instr     = memwb_instr;
  assign trace_rd_addr   = memwb_rd;
  assign trace_rd_wdata  = memwb_rd_wdata;
  assign trace_rd_we     = memwb_rd_we && memwb_valid && !dcache_stall;
  assign trace_mem_addr  = memwb_alu_res;
  assign trace_mem_wdata = memwb_wdata;
  assign trace_mem_wmask = memwb_wmask;
  assign trace_trap      = trap_flush && memwb_valid; // Needs sync to exact retiring instruction
`endif

endmodule
