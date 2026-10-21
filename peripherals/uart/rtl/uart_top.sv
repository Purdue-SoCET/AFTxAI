`timescale 1ns/1ps

module uart_top #(
    parameter CLOCK_FREQ_HZ = 50000000,
    parameter DEFAULT_BAUD  = 115200,
    parameter FIFO_DEPTH    = 16,
    parameter ADDR_WIDTH    = 8,
    parameter DATA_WIDTH    = 32
)(
    uart_if.target vif
);
    // ------------------------------------------------------------------------
    // Registers (Basic Memory Map as per docs/uart.md)
    // ------------------------------------------------------------------------
    logic [31:0] int_enable_q, int_enable_d;
    logic [31:0] line_ctrl_q, line_ctrl_d;
    logic [31:0] mode_ctrl_q, mode_ctrl_d;
    logic [31:0] baud_div_q, baud_div_d;
    logic [31:0] prdata_d;
    logic        pready_d;

    localparam int OVERSAMPLE = 16;
    localparam int DEFAULT_DIV = CLOCK_FREQ_HZ / (DEFAULT_BAUD * OVERSAMPLE);

    // Baud generator logic
    logic [15:0] baud_cnt_q, baud_cnt_d;
    logic os_tick_q, os_tick_d;
    logic [3:0] baud_tick_cnt_q, baud_tick_cnt_d;
    logic baud_tick_q, baud_tick_d;

    // FIFO signals
    logic [7:0] tx_fifo_rdata;
    logic tx_fifo_full, tx_fifo_empty;
    logic tx_fifo_wr, tx_fifo_rd;
    logic [7:0] rx_fifo_rdata;
    logic rx_fifo_full, rx_fifo_empty;
    logic rx_fifo_wr, rx_fifo_rd;

    // TX / RX interface signals
    logic tx_ready, tx_out;
    logic rx_valid;
    logic [7:0] rx_data;

    // Instantiations
    uart_fifo #(.DATA_WIDTH(8), .DEPTH(FIFO_DEPTH)) tx_fifo (
        .clk(vif.clk), .rst_n(vif.rst_n), .clear(1'b0), // Tie off clear for now
        .wr_en(tx_fifo_wr), .wr_data(vif.pwdata[7:0]),
        .rd_en(tx_fifo_rd), .rd_data(tx_fifo_rdata),
        .full(tx_fifo_full), .empty(tx_fifo_empty)
    );

    uart_fifo #(.DATA_WIDTH(8), .DEPTH(FIFO_DEPTH)) rx_fifo (
        .clk(vif.clk), .rst_n(vif.rst_n), .clear(1'b0),
        .wr_en(rx_fifo_wr), .wr_data(rx_data),
        .rd_en(rx_fifo_rd), .rd_data(rx_fifo_rdata),
        .full(rx_fifo_full), .empty(rx_fifo_empty)
    );

    uart_tx tx_inst (
        .clk(vif.clk), .rst_n(vif.rst_n),
        .baud_tick(baud_tick_q),
        .tx_data(tx_fifo_rdata),
        .tx_valid(~tx_fifo_empty),
        .tx_ready(tx_ready),
        .tx_out(tx_out)
    );

    uart_rx #(.OVERSAMPLE(OVERSAMPLE)) rx_inst (
        .clk(vif.clk), .rst_n(vif.rst_n),
        .os_tick(os_tick_q),
        .rx_in(vif.rx),
        .rx_data(rx_data),
        .rx_valid(rx_valid)
    );

    // TX FIFO read logic
    assign tx_fifo_rd = tx_ready && ~tx_fifo_empty && baud_tick_q;
    assign rx_fifo_wr = rx_valid && ~rx_fifo_full;

    assign vif.tx = tx_out;
    assign vif.rts_n = rx_fifo_full; // Simple auto-RTS

    // Top Level Comb
    always_comb begin
        int_enable_d = int_enable_q;
        line_ctrl_d  = line_ctrl_q;
        mode_ctrl_d  = mode_ctrl_q;
        baud_div_d   = baud_div_q;

        // Baud Generation
        baud_cnt_d      = baud_cnt_q;
        os_tick_d       = 1'b0;
        baud_tick_d     = 1'b0;
        baud_tick_cnt_d = baud_tick_cnt_q;
        
        if (baud_cnt_q >= baud_div_q[15:0] - 1) begin
            baud_cnt_d = '0;
            os_tick_d  = 1'b1;
            if (baud_tick_cnt_q == OVERSAMPLE - 1) begin
                baud_tick_cnt_d = '0;
                baud_tick_d     = 1'b1;
            end else begin
                baud_tick_cnt_d = baud_tick_cnt_q + 1;
            end
        end else begin
            baud_cnt_d = baud_cnt_q + 1;
        end

        // Bus Interface
        prdata_d     = '0;
        pready_d     = 1'b1;
        tx_fifo_wr   = 1'b0;
        rx_fifo_rd   = 1'b0;

        if (vif.psel && vif.penable) begin
            if (vif.pwrite) begin
                case (vif.paddr)
                    8'h00: tx_fifo_wr = ~tx_fifo_full;
                    8'h04: int_enable_d = vif.pwdata;
                    8'h0C: line_ctrl_d  = vif.pwdata;
                    8'h10: mode_ctrl_d  = vif.pwdata;
                    8'h1C: baud_div_d   = vif.pwdata;
                    default: ;
                endcase
            end else begin
                case (vif.paddr)
                    8'h00: begin
                        prdata_d = {24'h0, rx_fifo_rdata};
                        rx_fifo_rd = ~rx_fifo_empty;
                    end
                    8'h04: prdata_d = int_enable_q;
                    8'h0C: prdata_d = line_ctrl_q;
                    8'h10: prdata_d = mode_ctrl_q;
                    // THRE (bit 5) = empty, TEMT (bit 6) = empty && ready
                    8'h14: prdata_d = {25'h0, tx_fifo_empty && tx_ready, tx_fifo_empty, 4'h0, ~rx_fifo_empty}; 
                    8'h1C: prdata_d = baud_div_q;
                    default: prdata_d = 32'h0;
                endcase
            end
        end

        // Basic IRQ implementation
        vif.irq = (int_enable_q[0] && ~rx_fifo_empty) || (int_enable_q[1] && tx_fifo_empty);
    end

    // FF
    always_ff @(posedge vif.clk or negedge vif.rst_n) begin
        if (!vif.rst_n) begin
            int_enable_q <= '0;
            line_ctrl_q  <= 32'h03;
            mode_ctrl_q  <= '0;
            baud_div_q   <= DEFAULT_DIV;
            baud_cnt_q   <= '0;
            os_tick_q    <= '0;
            baud_tick_cnt_q <= '0;
            baud_tick_q  <= '0;
            vif.prdata   <= '0;
            vif.pready   <= '0;
            vif.pslverr  <= '0;
        end else begin
            int_enable_q <= int_enable_d;
            line_ctrl_q  <= line_ctrl_d;
            mode_ctrl_q  <= mode_ctrl_d;
            baud_div_q   <= baud_div_d;
            baud_cnt_q   <= baud_cnt_d;
            os_tick_q    <= os_tick_d;
            baud_tick_cnt_q <= baud_tick_cnt_d;
            baud_tick_q  <= baud_tick_d;
            vif.prdata   <= prdata_d;
            vif.pready   <= pready_d;
            vif.pslverr  <= 1'b0;
        end
    end

endmodule
