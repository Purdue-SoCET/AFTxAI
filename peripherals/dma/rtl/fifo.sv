/* verilator lint_off UNUSEDSIGNAL */
/* verilator lint_off UNDRIVEN */
/* verilator lint_off UNUSEDPARAM */
`timescale 1ns/1ps

module fifo #(
    parameter int WIDTH = 66,
    parameter int DEPTH = 8
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             clear,
    
    input  logic             push,
    input  logic [WIDTH-1:0] data_in,
    output logic             full,
    
    input  logic             pop,
    output logic [WIDTH-1:0] data_out,
    output logic             empty
);
    localparam int ADDR_W = $clog2(DEPTH);
    
    logic [WIDTH-1:0] mem [DEPTH];
    logic [ADDR_W:0]  wr_ptr, rd_ptr;
    
    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[ADDR_W] != rd_ptr[ADDR_W]) && (wr_ptr[ADDR_W-1:0] == rd_ptr[ADDR_W-1:0]);
    assign data_out = mem[rd_ptr[ADDR_W-1:0]];
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
        end else if (clear) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
        end else begin
            if (push && !full) begin
                mem[wr_ptr[ADDR_W-1:0]] <= data_in;
                wr_ptr <= wr_ptr + 1'b1;
            end
            if (pop && !empty) begin
                rd_ptr <= rd_ptr + 1'b1;
            end
        end
    end
endmodule
