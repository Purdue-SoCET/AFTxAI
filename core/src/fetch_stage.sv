`timescale 1ns/1ps

module fetch_stage (
    input  logic clk,
    input  logic rst_n,

    // Interface to execute stage
    fetch_exec_if.fetch fe_if,

    // Control signals from hazard unit / branch execution
    input  logic        stall,
    input  logic        flush,
    input  logic        branch_mispredict,
    input  logic [31:0] correct_target_pc,

    // Instruction Memory / Cache Interface (Simplified)
    output logic [31:0] imem_addr,
    input  logic [31:0] imem_rdata,
    input  logic        imem_valid,

    // Interface from branch predictor
    output logic [31:0] bp_pc,
    input  logic        bp_taken,
    input  logic [31:0] bp_target
);

    logic [31:0] pc_reg;
    logic [31:0] next_pc;

    assign bp_pc = pc_reg;
    assign imem_addr = pc_reg;

    always_comb begin
        if (branch_mispredict) begin
            next_pc = correct_target_pc;
        end else if (bp_taken) begin
            next_pc = bp_target;
        end else begin
            // Assuming 32-bit instructions for now. 
            // C extension (16-bit) support will dynamically adjust pc increment.
            next_pc = pc_reg + 32'd4; 
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_reg <= 32'h0;
            fe_if.inst_valid <= 1'b0;
        end else if (!stall) begin
            pc_reg <= next_pc;
            if (flush) begin
                fe_if.inst_valid <= 1'b0;
            end else begin
                fe_if.pc <= pc_reg;
                fe_if.instruction <= imem_rdata; // Expand for C-ext alignment later
                fe_if.predicted_taken <= bp_taken;
                fe_if.predicted_target <= bp_target;
                fe_if.inst_valid <= imem_valid;
            end
        end
    end

endmodule
