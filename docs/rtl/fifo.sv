module fifo #(
    parameter DATA_WIDTH = 66,
    parameter DEPTH = 8
)(
    input  logic clk,
    input  logic rst_n,
    input  logic clear,
    
    input  logic push,
    input  logic [DATA_WIDTH-1:0] data_in,
    output logic full,
    
    input  logic pop,
    output logic [DATA_WIDTH-1:0] data_out,
    output logic empty
);
    localparam ADDR_W = $clog2(DEPTH);
    
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    logic [ADDR_W:0] wptr, rptr;
    
    assign full = (wptr[ADDR_W-1:0] == rptr[ADDR_W-1:0]) && (wptr[ADDR_W] != rptr[ADDR_W]);
    assign empty = (wptr == rptr);
    assign data_out = mem[rptr[ADDR_W-1:0]];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wptr <= '0;
            rptr <= '0;
        end else if (clear) begin
            wptr <= '0;
            rptr <= '0;
        end else begin
            if (push && !full) begin
                mem[wptr[ADDR_W-1:0]] <= data_in;
                wptr <= wptr + 1'b1;
            end
            if (pop && !empty) begin
                rptr <= rptr + 1'b1;
            end
        end
    end
endmodule
