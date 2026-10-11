`timescale 1ns/1ps

module branch_predictor #(
    parameter int BHT_ENTRIES = 64
) (
    input  logic        HCLK,
    input  logic        nRST,
    
    // Prediction Port
    input  logic [31:0] fetch_pc,
    output logic        predict_taken,
    
    // Update Port
    input  logic        update_valid,
    input  logic [31:0] update_pc,
    input  logic        update_taken
);

    // TODO: Implement 2-bit saturating bimodal counter logic
    always_comb begin
        predict_taken = 1'b0;
    end

endmodule
