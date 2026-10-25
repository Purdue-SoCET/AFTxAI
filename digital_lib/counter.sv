module counter #(
    parameter int NBITS = 8
)(
    input  logic CLK,
    input  logic nRST,
    input  logic clear,
    input  logic count_enable,
    input  logic [NBITS-1:0] overflow_val,
    output logic [NBITS-1:0] count_out,
    output logic overflow_flag
);

    logic [NBITS-1:0] count_d;
    logic [NBITS-1:0] count_q;

    assign count_out = count_q;

    // Next-state logic per project rules
    always_comb begin
        count_d = count_q;
        overflow_flag = 1'b0;

        if (count_q >= overflow_val) begin
            overflow_flag = 1'b1;
        end

        if (clear) begin
            count_d = '0;
        end else if (count_enable) begin
            if (count_q >= overflow_val) begin
                count_d = '0;
            end else begin
                count_d = count_q + 1'b1;
            end
        end
    end

    // Sequential flip-flops
    always_ff @(posedge CLK or negedge nRST) begin
        if (!nRST) begin
            count_q <= '0;
        end else begin
            count_q <= count_d;
        end
    end

endmodule
