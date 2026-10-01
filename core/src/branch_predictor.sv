`timescale 1ns/1ps

module branch_predictor (
    input  logic        clk,
    input  logic        rst_n,
    
    // Prediction Interface
    input  logic [31:0] pc,
    output logic        predict_taken,
    output logic [31:0] predict_target,
    
    // Update Interface
    input  logic        update_valid,
    input  logic [31:0] update_pc,
    input  logic        update_taken,
    input  logic [31:0] update_target
);

    // Simple static prediction for now: backward branches are taken
    // A fully functional predictor would use a BHT and BTB.
    
    always_comb begin
        // Stub for branch prediction logic
        // E.g., predict taken if branch is backward
        predict_taken = 1'b0; 
        predict_target = pc + 4;
    end

endmodule