module counter #(
    parameter COUNT_W = 8
)(
    input  logic clk,
    input  logic rst_n,
    
    input  logic clear,
    input  logic inc,
    input  logic [COUNT_W-1:0] limit,
    
    output logic [COUNT_W-1:0] count,
    output logic done
);

    logic [COUNT_W-1:0] count_reg;
    
    assign count = count_reg;
    assign done = (count_reg >= limit) && (limit != '0);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count_reg <= '0;
        end else if (clear) begin
            count_reg <= '0;
        end else if (inc && !done) begin
            count_reg <= count_reg + 1'b1;
        end
    end

endmodule
