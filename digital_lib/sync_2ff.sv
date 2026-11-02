module sync_2ff #(
    parameter int WIDTH = 1
) (
    input  logic             pclk,
    input  logic             presetn,
    input  logic [WIDTH-1:0] d,
    output logic [WIDTH-1:0] q
);
    logic [WIDTH-1:0] q1_next;
    logic [WIDTH-1:0] q2_next;
    
    logic [WIDTH-1:0] q1;
    logic [WIDTH-1:0] q2;

    always_comb begin
        q1_next = d;
        q2_next = q1;
    end

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            q1 <= '0;
            q2 <= '0;
        end else begin
            q1 <= q1_next;
            q2 <= q2_next;
        end
    end

    assign q = q2;
endmodule