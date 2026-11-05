`timescale 1ns/1ps

/* verilator lint_off UNUSEDPARAM */
// Reason: FIFO_DEPTH is part of the spec but simplified in this stub implementation.
/* verilator lint_off UNUSEDSIGNAL */
// Reason: Not all AHB or UART interface signals (e.g. HMASTLOCK, HBURST) are needed.
/* verilator lint_off UNDRIVEN */
// Reason: Interfaces contain signals driven by the external testbench or interconnect.

module uart #(
    parameter CLOCK_FREQ_HZ = 50000000,
    parameter DEFAULT_BAUD  = 115200,
    parameter FIFO_DEPTH    = 16
) (
    ahb_if.subordinate ahb,
    uart_if.target uif
);

    logic clk;
    logic rst_n;
    
    assign clk = ahb.HCLK;
    assign rst_n = ahb.HRESETn;

    // -------------------------------------------------------------------------
    // AHB-Lite Interface Logic
    // -------------------------------------------------------------------------
    logic [31:0] haddr_reg, haddr_next;
    logic        hwrite_reg, hwrite_next;
    logic        hsel_reg, hsel_next;
    logic        htrans_reg, htrans_next;

    logic        we;
    logic        re;
    logic [7:0]  reg_addr;

    always_comb begin
        haddr_next  = ahb.HREADY ? ahb.HADDR : haddr_reg;
        hwrite_next = ahb.HREADY ? ahb.HWRITE : hwrite_reg;
        hsel_next   = ahb.HREADY ? ahb.HSEL : hsel_reg;
        htrans_next = ahb.HREADY ? ahb.HTRANS[1] : htrans_reg; // NONSEQ or SEQ
        
        we = hsel_reg && htrans_reg && hwrite_reg && ahb.HREADY;
        re = ahb.HSEL && ahb.HTRANS[1] && !ahb.HWRITE && ahb.HREADY;
        
        reg_addr = haddr_reg[7:0];
        
        ahb.HREADYOUT = 1'b1;
        ahb.HRESP = 1'b0;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            haddr_reg  <= '0;
            hwrite_reg <= '0;
            hsel_reg   <= '0;
            htrans_reg <= '0;
        end else begin
            haddr_reg  <= haddr_next;
            hwrite_reg <= hwrite_next;
            hsel_reg   <= hsel_next;
            htrans_reg <= htrans_next;
        end
    end

    // ------------------------------------------------------------------------
    // Registers & Control
    // ------------------------------------------------------------------------
    logic [31:0] int_enable_q, int_enable_d;
    logic [31:0] line_ctrl_q, line_ctrl_d;
    logic [31:0] mode_ctrl_q, mode_ctrl_d;
    logic [31:0] baud_div_q, baud_div_d;

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
        .clk(clk), .rst_n(rst_n), .clear(1'b0), // Tie off clear for now
        .wr_en(tx_fifo_wr), .wr_data(ahb.HWDATA[7:0]),
        .rd_en(tx_fifo_rd), .rd_data(tx_fifo_rdata),
        .full(tx_fifo_full), .empty(tx_fifo_empty)
    );

    uart_fifo #(.DATA_WIDTH(8), .DEPTH(FIFO_DEPTH)) rx_fifo (
        .clk(clk), .rst_n(rst_n), .clear(1'b0),
        .wr_en(rx_fifo_wr), .wr_data(rx_data),
        .rd_en(rx_fifo_rd), .rd_data(rx_fifo_rdata),
        .full(rx_fifo_full), .empty(rx_fifo_empty)
    );

    uart_tx tx_inst (
        .clk(clk), .rst_n(rst_n),
        .baud_tick(baud_tick_q),
        .tx_data(tx_fifo_rdata),
        .tx_valid(~tx_fifo_empty),
        .tx_ready(tx_ready),
        .tx_out(tx_out)
    );

    uart_rx #(.OVERSAMPLE(OVERSAMPLE)) rx_inst (
        .clk(clk), .rst_n(rst_n),
        .os_tick(os_tick_q),
        .rx_in(uif.rx),
        .rx_data(rx_data),
        .rx_valid(rx_valid)
    );

    // TX FIFO read logic
    assign tx_fifo_rd = tx_ready && ~tx_fifo_empty && baud_tick_q;
    assign rx_fifo_wr = rx_valid && ~rx_fifo_full;

    assign uif.tx = tx_out;
    assign uif.rts_n = rx_fifo_full; // Simple auto-RTS

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

        // Bus Write Interface
        tx_fifo_wr   = 1'b0;
        rx_fifo_rd   = 1'b0;

        if (we) begin
            case (reg_addr)
                8'h00: tx_fifo_wr = ~tx_fifo_full;
                8'h04: int_enable_d = ahb.HWDATA;
                8'h0C: line_ctrl_d  = ahb.HWDATA;
                8'h10: mode_ctrl_d  = ahb.HWDATA;
                8'h1C: baud_div_d   = ahb.HWDATA;
                default: ;
            endcase
        end

        // Bus Read Interface
        if (re) begin
            case (ahb.HADDR[7:0]) // Use ahb.HADDR directly for read as per AHB re logic
                8'h00: rx_fifo_rd = ~rx_fifo_empty;
                default: ;
            endcase
        end

        // Basic IRQ implementation
        uif.irq = (int_enable_q[0] && ~rx_fifo_empty) || (int_enable_q[1] && tx_fifo_empty);
    end

    // AHB HRDATA
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ahb.HRDATA <= '0;
        end else begin
            if (re) begin
                case (ahb.HADDR[7:0])
                    8'h00: ahb.HRDATA <= {24'h0, rx_fifo_rdata};
                    8'h04: ahb.HRDATA <= int_enable_q;
                    8'h0C: ahb.HRDATA <= line_ctrl_q;
                    8'h10: ahb.HRDATA <= mode_ctrl_q;
                    8'h14: ahb.HRDATA <= {25'h0, tx_fifo_empty && tx_ready, tx_fifo_empty, 4'h0, ~rx_fifo_empty}; 
                    8'h1C: ahb.HRDATA <= baud_div_q;
                    default: ahb.HRDATA <= 32'h0;
                endcase
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            int_enable_q <= '0;
            line_ctrl_q  <= 32'h03;
            mode_ctrl_q  <= '0;
            baud_div_q   <= DEFAULT_DIV;
            baud_cnt_q   <= '0;
            os_tick_q    <= '0;
            baud_tick_cnt_q <= '0;
            baud_tick_q  <= '0;
        end else begin
            int_enable_q <= int_enable_d;
            line_ctrl_q  <= line_ctrl_d;
            mode_ctrl_q  <= mode_ctrl_d;
            baud_div_q   <= baud_div_d;
            baud_cnt_q   <= baud_cnt_d;
            os_tick_q    <= os_tick_d;
            baud_tick_cnt_q <= baud_tick_cnt_d;
            baud_tick_q  <= baud_tick_d;
        end
    end

endmodule