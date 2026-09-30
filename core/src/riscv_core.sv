`timescale 1ns/1ps

module riscv_core (
    input  logic clk,
    input  logic rst_n,

    // Instruction Memory Interface
    output logic [31:0] imem_addr,
    input  logic [31:0] imem_rdata,
    input  logic        imem_valid,

    // Data Memory Interface
    output logic [31:0] dmem_addr,
    output logic [31:0] dmem_wdata,
    output logic        dmem_read,
    output logic        dmem_write,
    output logic [2:0]  dmem_size,
    input  logic [31:0] dmem_rdata,
    input  logic        dmem_ready
);

    // Interfaces
    fetch_exec_if fe_if();
    exec_mem_if   em_if();
    mem_wb_if     mwb_if();

    // Internal signals
    logic stall_fetch;
    logic flush_execute;
    logic branch_mispredict;
    logic [31:0] correct_target_pc;
    
    logic [4:0] ex_rs1_addr;
    logic [4:0] ex_rs2_addr;
    logic       use_forward_a;
    logic       use_forward_b;
    logic [31:0] forward_a_val;
    logic [31:0] forward_b_val;

    logic [31:0] bp_pc;
    logic        bp_taken;
    logic [31:0] bp_target;

    branch_predictor bp (
        .clk(clk),
        .rst_n(rst_n),
        .pc(bp_pc),
        .predict_taken(bp_taken),
        .predict_target(bp_target),
        .update_valid(em_if.valid), // Simplified update
        .update_pc(fe_if.pc),
        .update_taken(1'b0), // Connect properly later
        .update_target(32'h0)
    );

    fetch_stage fetch (
        .clk(clk),
        .rst_n(rst_n),
        .fe_if(fe_if.fetch),
        .stall(stall_fetch),
        .flush(branch_mispredict),
        .branch_mispredict(branch_mispredict),
        .correct_target_pc(correct_target_pc),
        .imem_addr(imem_addr),
        .imem_rdata(imem_rdata),
        .imem_valid(imem_valid),
        .bp_pc(bp_pc),
        .bp_taken(bp_taken),
        .bp_target(bp_target)
    );

    execute_stage execute (
        .clk(clk),
        .rst_n(rst_n),
        .fe_if(fe_if.exec),
        .em_if(em_if.exec),
        .mwb_if(mwb_if.exec),
        .flush(flush_execute),
        .rs1_addr(ex_rs1_addr),
        .rs2_addr(ex_rs2_addr),
        .forward_a_val(forward_a_val),
        .forward_b_val(forward_b_val),
        .use_forward_a(use_forward_a),
        .use_forward_b(use_forward_b),
        .branch_mispredict(branch_mispredict),
        .correct_target_pc(correct_target_pc)
    );

    memory_stage memory (
        .clk(clk),
        .rst_n(rst_n),
        .em_if(em_if.mem),
        .mwb_if(mwb_if.mem),
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_read(dmem_read),
        .dmem_write(dmem_write),
        .dmem_size(dmem_size),
        .dmem_rdata(dmem_rdata),
        .dmem_ready(dmem_ready)
    );

    hazard_unit hazard (
        .fe_rs1_addr(ex_rs1_addr), // Using decoded addresses from Exec
        .fe_rs2_addr(ex_rs2_addr),
        .em_mem_read_en(em_if.mem_read_en),
        .em_rd_addr(em_if.rd_addr),
        .branch_mispredict(branch_mispredict),
        .stall_fetch(stall_fetch),
        .flush_execute(flush_execute)
    );

    forwarding_unit forwarding (
        .ex_rs1_addr(ex_rs1_addr),
        .ex_rs2_addr(ex_rs2_addr),
        .mem_rd_addr(mwb_if.rd_addr),
        .mem_reg_write_en(mwb_if.reg_write_en),
        .mem_writeback_data(mwb_if.writeback_data),
        .use_forward_a(use_forward_a),
        .forward_a_val(forward_a_val),
        .use_forward_b(use_forward_b),
        .forward_b_val(forward_b_val)
    );

endmodule
