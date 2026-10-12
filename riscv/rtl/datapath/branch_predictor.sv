`timescale 1ns/1ps
module branch_predictor #(parameter int BHT_ENTRIES = 64) (
    input logic HCLK, input logic nRST,
    branch_predictor_if.mp port
);
    localparam int IDX_BITS = $clog2(BHT_ENTRIES);
    logic [1:0] bht [BHT_ENTRIES-1:0];
    logic [1:0] next_bht [BHT_ENTRIES-1:0];
    logic [IDX_BITS-1:0] fetch_idx, update_idx;

    assign fetch_idx = port.fetch_pc[2 +: IDX_BITS];
    assign update_idx = port.update_pc[2 +: IDX_BITS];
    assign port.predict_taken = bht[fetch_idx][1];

    always_comb begin
        next_bht = bht;
        if (port.update_valid) begin
            if (port.update_taken) begin
                if (bht[update_idx] != 2'b11) next_bht[update_idx] = bht[update_idx] + 2'd1;
            end else begin
                if (bht[update_idx] != 2'b00) next_bht[update_idx] = bht[update_idx] - 2'd1;
            end
        end
    end

    always_ff @(posedge HCLK or negedge nRST) begin
        if (!nRST) begin
            for (int i = 0; i < BHT_ENTRIES; i++) bht[i] <= 2'b01;
        end else begin
            bht <= next_bht;
        end
    end
endmodule
