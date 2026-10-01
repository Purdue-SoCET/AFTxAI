`timescale 1ns/1ps

module fetch_stage (
    input  logic clk,
    input  logic rst_n,

    // Interface
    fetch_exec_if.fetch fe_if,

    // Control
    input  logic stall,
    input  logic flush,
    input  logic branch_mispredict,
    input  logic [31:0] correct_target_pc,

    // Instruction Cache Interface
    output logic [31:0] icache_addr,
    output logic        icache_req,
    input  logic [31:0] icache_rdata,
    input  logic        icache_valid,

    // Branch Predictor Interface
    output logic [31:0] bp_pc,
    input  logic        bp_taken,
    input  logic [31:0] bp_target
);

    logic [31:0] pc_reg, next_pc;

    assign bp_pc = pc_reg;
    assign icache_addr = pc_reg;
    assign icache_req = 1'b1;

    always_comb begin
        if (branch_mispredict) begin
            next_pc = correct_target_pc;
        end else if (bp_taken && icache_valid) begin
            next_pc = bp_target;
        end else if (icache_valid && !stall) begin
            next_pc = pc_reg + 4;
        end else begin
            next_pc = pc_reg;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_reg <= 32'h0;
        end else if (!stall || branch_mispredict) begin
            pc_reg <= next_pc;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fe_if.pc <= 32'h0;
            fe_if.instruction <= 32'h13; // NOP
            fe_if.inst_valid <= 1'b0;
            fe_if.predicted_taken <= 1'b0;
            fe_if.predicted_target <= 32'h0;
        end else if (flush) begin
            fe_if.pc <= 32'h0;
            fe_if.instruction <= 32'h13; // NOP
            fe_if.inst_valid <= 1'b0;
            fe_if.predicted_taken <= 1'b0;
            fe_if.predicted_target <= 32'h0;
        end else if (!stall) begin
            fe_if.pc <= pc_reg;
            fe_if.instruction <= icache_valid ? icache_rdata : 32'h13;
            fe_if.inst_valid <= icache_valid;
            fe_if.predicted_taken <= bp_taken;
            fe_if.predicted_target <= bp_target;
        end
    end

endmodule