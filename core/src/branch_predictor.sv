`timescale 1ns/1ps

module branch_predictor (
    input  logic clk,
    input  logic rst_n,

    // Prediction interface
    input  logic [31:0] pc,
    output logic        predict_taken,
    output logic [31:0] predict_target,

    // Update interface from Execute stage
    input  logic        update_valid,
    input  logic [31:0] update_pc,
    input  logic        update_taken,
    input  logic [31:0] update_target
);

    // Simple static prediction or 1-bit/2-bit BTB can be implemented here.
    // Defaulting to always not-taken for skeleton.
    assign predict_taken = 1'b0;
    assign predict_target = 32'd0;

endmodule
