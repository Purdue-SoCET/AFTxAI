`ifndef SYNC_2FF_SV
`define SYNC_2FF_SV

module sync_2ff #(
    parameter int WIDTH = 1
) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic [WIDTH-1:0] d_in,
    output logic [WIDTH-1:0] d_out
);

    logic [WIDTH-1:0] q1, q2;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q1 <= '0;
            q2 <= '0;
        end else begin
            q1 <= d_in;
            q2 <= q1;
        end
    end

    assign d_out = q2;

endmodule

`endif
