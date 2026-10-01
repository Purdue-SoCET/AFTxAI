`timescale 1ns/1ps
import riscv_pkg::*;

module datapath #(
  parameter bit RV32E = 0,
  parameter logic [31:0] BOOT_ADDR = 32'h0000_0000
)(
  input  logic clk,
  input  logic rst_n,
  
  // Cache Interfaces (Using the cpu_cache_if modports)
  // We break them out here to avoid interface array issues in some tools
  output logic [31:0] icache_req_addr,
  output logic        icache_req_valid,
  input  logic        icache_req_ready,
  input  logic [31:0] icache_resp_data,
  input  logic        icache_resp_valid,
  
  output logic [31:0] dcache_req_addr,
  output logic [31:0] dcache_req_data,
  output logic [3:0]  dcache_req_be,
  output logic        dcache_req_write,
  output logic        dcache_req_valid,
  input  logic        dcache_req_ready,
  input  logic [31:0] dcache_resp_data,
  input  logic        dcache_resp_valid
);

  // --------------------------------------------------------
  // Pipeline Registers & Signals
  // --------------------------------------------------------
  // IF stage
  logic [31:0] pc_reg, next_pc, pc_plus_4;
  logic [31:0] instr_if;
  
  // IF/ID Pipeline Register
  logic [31:0] if_id_pc, if_id_instr, if_id_pc_plus_4;
  
  // ID/EX Signals
  logic [31:0] rs1_data, rs2_data, imm_val;
  alu_op_t     alu_op;
  logic        alu_src, reg_write, mem_write, mem_read, branch, jump;
  logic [1:0]  result_src;
  branch_type_t branch_type;
  
  logic [31:0] alu_a, alu_b, alu_result;
  logic        take_branch;
  logic [31:0] branch_target;
  
  // ID/EX to MEM/WB Pipeline Register (Since it's 3-stage)
  logic [31:0] ex_mem_alu_result, ex_mem_rs2_data, ex_mem_pc_plus_4;
  logic [4:0]  ex_mem_rd;
  logic        ex_mem_reg_write, ex_mem_mem_write, ex_mem_mem_read;
  logic [1:0]  ex_mem_result_src;
  
  // Hazards & Forwarding
  logic stall_if, stall_id, stall_ex, flush_if, flush_id;
  logic forward_a, forward_b;
  logic [31:0] fw_a_val, fw_b_val;
  
  // Writeback
  logic [31:0] writeback_data;
  
  // --------------------------------------------------------
  // IF Stage
  // --------------------------------------------------------
  assign pc_plus_4 = pc_reg + 4;
  assign branch_target = (if_id_instr[6:0] == OP_JALR) ? (fw_a_val + imm_val) & ~32'b1 : if_id_pc + imm_val;
  
  assign next_pc = (take_branch || jump) ? branch_target : pc_plus_4;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc_reg <= BOOT_ADDR;
    end else if (!stall_if) begin
      pc_reg <= next_pc;
    end
  end
  
  assign icache_req_addr  = pc_reg;
  assign icache_req_valid = 1'b1; // Always request the current PC
  assign instr_if = icache_resp_data;

  // IF/ID Register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush_if) begin
      if_id_pc        <= 32'b0;
      if_id_instr     <= 32'h00000013; // NOP
      if_id_pc_plus_4 <= 32'b0;
    end else if (!stall_id) begin
      if_id_pc        <= pc_reg;
      if_id_instr     <= instr_if;
      if_id_pc_plus_4 <= pc_plus_4;
      $display("Time=%0t: IF/ID Pipeline advanced. PC=0x%0h, Instr=0x%0h", $time, pc_reg, instr_if);
    end
  end
  
  // --------------------------------------------------------
  // ID/EX Stage
  // --------------------------------------------------------
  logic [4:0] rs1, rs2, rd;
  assign rs1 = if_id_instr[19:15];
  assign rs2 = if_id_instr[24:20];
  assign rd  = if_id_instr[11:7];

  control_unit ctrl_inst (
    .instr_i(if_id_instr),
    .alu_op_o(alu_op),
    .alu_src_o(alu_src),
    .reg_write_o(reg_write),
    .mem_write_o(mem_write),
    .mem_read_o(mem_read),
    .result_src_o(result_src),
    .branch_o(branch),
    .jump_o(jump),
    .branch_type_o(branch_type)
  );

  imm_gen imm_inst (
    .instr_i(if_id_instr),
    .imm_o(imm_val)
  );

  regfile #(.RV32E(RV32E)) rf_inst (
    .clk(clk),
    .rst_n(rst_n),
    .rs1_addr_i(rs1),
    .rs1_data_o(rs1_data),
    .rs2_addr_i(rs2),
    .rs2_data_o(rs2_data),
    .rd_addr_i(ex_mem_rd),
    .rd_data_i(writeback_data),
    .rd_we_i(ex_mem_reg_write)
  );

  // Forwarding Muxes
  assign fw_a_val = forward_a ? writeback_data : rs1_data;
  assign fw_b_val = forward_b ? writeback_data : rs2_data;

  // LUI / AUIPC special handling for ALU A
  logic use_pc, use_zero;
  assign use_pc = (if_id_instr[6:0] == OP_AUIPC || if_id_instr[6:0] == OP_JAL);
  assign use_zero = (if_id_instr[6:0] == OP_LUI);
  
  assign alu_a = use_pc ? if_id_pc : (use_zero ? 32'b0 : fw_a_val);
  assign alu_b = alu_src ? imm_val : fw_b_val;

  alu alu_inst (
    .a_i(alu_a),
    .b_i(alu_b),
    .alu_op_i(alu_op),
    .result_o(alu_result)
  );

  logic take_branch_o_internal;
  
  branch_res br_inst (
    .rs1_data_i(fw_a_val),
    .rs2_data_i(fw_b_val),
    .branch_type_i(branch_type),
    .take_branch_o(take_branch_o_internal)
  );
  assign take_branch = branch && take_branch_o_internal;

  hazard_unit haz_inst (
    .icache_ready_i(icache_req_ready),
    .dcache_ready_i(dcache_req_ready),
    .dcache_valid_req_i(ex_mem_mem_read || ex_mem_mem_write),
    .if_id_rs1_i(rs1),
    .if_id_rs2_i(rs2),
    .id_ex_rd_i(ex_mem_rd),
    .id_ex_mem_read_i(ex_mem_mem_read),
    .branch_taken_i(take_branch),
    .jump_i(jump),
    .stall_if_o(stall_if),
    .stall_id_o(stall_id),
    .stall_ex_o(stall_ex),
    .flush_if_o(flush_if),
    .flush_id_o(flush_id)
  );

  forwarding_unit fwd_inst (
    .id_ex_rs1_i(rs1),
    .id_ex_rs2_i(rs2),
    .ex_mem_rd_i(ex_mem_rd),
    .ex_mem_reg_write_i(ex_mem_reg_write),
    .forward_a_o(forward_a),
    .forward_b_o(forward_b)
  );

  // EX/MEM Pipeline Register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush_id) begin
      ex_mem_alu_result <= 32'b0;
      ex_mem_rs2_data   <= 32'b0;
      ex_mem_rd         <= 5'b0;
      ex_mem_reg_write  <= 1'b0;
      ex_mem_mem_write  <= 1'b0;
      ex_mem_mem_read   <= 1'b0;
      ex_mem_result_src <= 2'b00;
      ex_mem_pc_plus_4  <= 32'b0;
    end else if (!stall_ex) begin
      ex_mem_alu_result <= alu_result;
      ex_mem_rs2_data   <= fw_b_val;
      ex_mem_rd         <= rd;
      ex_mem_reg_write  <= reg_write;
      ex_mem_mem_write  <= mem_write;
      ex_mem_mem_read   <= mem_read;
      ex_mem_result_src <= result_src;
      ex_mem_pc_plus_4  <= if_id_pc_plus_4;
    end
  end

  // --------------------------------------------------------
  // MEM/WB Stage
  // --------------------------------------------------------
  assign dcache_req_addr  = ex_mem_alu_result;
  assign dcache_req_data  = ex_mem_rs2_data;
  assign dcache_req_write = ex_mem_mem_write;
  assign dcache_req_valid = ex_mem_mem_read || ex_mem_mem_write;
  assign dcache_req_be    = 4'b1111; // Simplified: always word access for now

  always_comb begin
    case (ex_mem_result_src)
      2'b00: writeback_data = ex_mem_alu_result;
      2'b01: writeback_data = dcache_resp_data; // Loaded data
      2'b10: writeback_data = ex_mem_pc_plus_4; // JAL/JALR
      default: writeback_data = 32'b0;
    endcase
  end

endmodule