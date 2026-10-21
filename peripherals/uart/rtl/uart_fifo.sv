`timescale 1ns/1ps

module uart_fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH = 16
)(
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  clear,
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic                  full,
    output logic                  empty
);
    localparam ADDR_W = $clog2(DEPTH);

    logic [DATA_WIDTH-1:0] mem_q [DEPTH-1:0];
    logic [DATA_WIDTH-1:0] mem_d [DEPTH-1:0];

    logic [ADDR_W:0] count_q, count_d;
    logic [ADDR_W-1:0] wr_ptr_q, wr_ptr_d;
    logic [ADDR_W-1:0] rd_ptr_q, rd_ptr_d;

    assign full  = (count_q == DEPTH);
    assign empty = (count_q == 0);
    assign rd_data = mem_q[rd_ptr_q];

    always_comb begin
        count_d  = count_q;
        wr_ptr_d = wr_ptr_q;
        rd_ptr_d = rd_ptr_q;
        for (int i = 0; i < DEPTH; i++) begin
            mem_d[i] = mem_q[i];
        end

        if (clear) begin
            count_d  = '0;
            wr_ptr_d = '0;
            rd_ptr_d = '0;
        end else begin
            case ({wr_en & ~full, rd_en & ~empty})
                2'b10: begin // Write only
                    mem_d[wr_ptr_q] = wr_data;
                    wr_ptr_d = wr_ptr_q + 1;
                    count_d  = count_q + 1;
                end
                2'b01: begin // Read only
                    rd_ptr_d = rd_ptr_q + 1;
                    count_d  = count_q - 1;
                end
                2'b11: begin // Read and Write
                    mem_d[wr_ptr_q] = wr_data;
                    wr_ptr_d = wr_ptr_q + 1;
                    rd_ptr_d = rd_ptr_q + 1;
                end
                default: ; // Do nothing
            endcase
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count_q  <= '0;
            wr_ptr_q <= '0;
            rd_ptr_q <= '0;
            for (int i = 0; i < DEPTH; i++) begin
                mem_q[i] <= '0;
            end
        end else begin
            count_q  <= count_d;
            wr_ptr_q <= wr_ptr_d;
            rd_ptr_q <= rd_ptr_d;
            for (int i = 0; i < DEPTH; i++) begin
                mem_q[i] <= mem_d[i];
            end
        end
    end

endmodule
