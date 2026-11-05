/* verilator lint_off UNUSEDSIGNAL */
/* verilator lint_off UNDRIVEN */
/* verilator lint_off UNUSEDPARAM */
`timescale 1ns/1ps

module dma_counter #(
    parameter int COUNT_W = 8
)(
    input  logic               clk,
    input  logic               rst_n,
    input  logic               clear,
    input  logic               inc,
    output logic [COUNT_W-1:0] count
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= '0;
        end else if (clear) begin
            count <= '0;
        end else if (inc) begin
            count <= count + 1'b1;
        end
    end
endmodule
