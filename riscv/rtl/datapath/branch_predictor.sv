`timescale 1ns/1ps

module branch_predictor #(
    parameter int BHT_ENTRIES = 64
) (
    input  logic        HCLK,
    input  logic        nRST,
    
    // Prediction Port (Combinational)
    input  logic [31:0] fetch_pc,
    output logic        predict_taken,
    
    // Update Port (Synchronous)
    input  logic        update_valid,
    input  logic [31:0] update_pc,
    input  logic        update_taken
);

    localparam int IDX_BITS = $clog2(BHT_ENTRIES);
    
    logic [1:0] bht [BHT_ENTRIES-1:0];

    logic [IDX_BITS-1:0] fetch_idx;
    logic [IDX_BITS-1:0] update_idx;

    // Word-aligned indexing (skip lowest 2 bits)
    assign fetch_idx  = fetch_pc[2 +: IDX_BITS];
    assign update_idx = update_pc[2 +: IDX_BITS];

    // Predict taken if the counter's MSB is 1 (Strong/Weak Taken)
    assign predict_taken = bht[fetch_idx][1];

    always_ff @(posedge HCLK or negedge nRST) begin
        if (!nRST) begin
            for (int i = 0; i < BHT_ENTRIES; i++) begin
                // Initialize to Weakly Not Taken
                bht[i] <= 2'b01;
            end
        end else if (update_valid) begin
            if (update_taken) begin
                if (bht[update_idx] != 2'b11) begin
                    bht[update_idx] <= bht[update_idx] + 2'd1;
                end
            end else begin
                if (bht[update_idx] != 2'b00) begin
                    bht[update_idx] <= bht[update_idx] - 2'd1;
                end
            end
        end
    end

endmodule
