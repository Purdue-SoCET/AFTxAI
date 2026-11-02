`timescale 1ns/1ps

/* verilator lint_off UNUSEDPARAM */
// Reason: FIFO_DEPTH is part of the spec but simplified in this stub implementation.
/* verilator lint_off UNUSEDSIGNAL */
// Reason: Not all AHB or UART interface signals (e.g. HMASTLOCK, HBURST, rx, cts_n) are needed in this basic configuration.
/* verilator lint_off UNDRIVEN */
// Reason: Interfaces contain signals driven by the external testbench or interconnect.

module uart #(
    parameter int FIFO_DEPTH = 16
) (
    ahb_if.subordinate ahb,
    uart_if.port uif
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

    // -------------------------------------------------------------------------
    // Registers
    // -------------------------------------------------------------------------
    logic [31:0] int_enable, int_enable_next;
    logic [31:0] line_ctrl, line_ctrl_next;
    logic [31:0] mode_ctrl, mode_ctrl_next;
    logic [31:0] scratch, scratch_next;
    logic [31:0] baud_div_lo, baud_div_lo_next;
    
    // Status
    logic [31:0] line_status, line_status_next;
    logic [31:0] hrdata_next;

    always_comb begin
        int_enable_next  = int_enable;
        line_ctrl_next   = line_ctrl;
        mode_ctrl_next   = mode_ctrl;
        scratch_next     = scratch;
        baud_div_lo_next = baud_div_lo;
        
        if (we) begin
            case (reg_addr)
                8'h04: int_enable_next  = ahb.HWDATA;
                8'h0C: line_ctrl_next   = ahb.HWDATA;
                8'h10: mode_ctrl_next   = ahb.HWDATA;
                8'h1C: scratch_next     = ahb.HWDATA;
                8'h20: baud_div_lo_next = ahb.HWDATA;
                default: ;
            endcase
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            int_enable  <= '0;
            line_ctrl   <= 32'h03; // 8 data bits, 1 stop bit, no parity
            mode_ctrl   <= '0;
            scratch     <= '0;
            baud_div_lo <= 32'd27; // Default for 115200 at 50MHz
        end else begin
            int_enable  <= int_enable_next;
            line_ctrl   <= line_ctrl_next;
            mode_ctrl   <= mode_ctrl_next;
            scratch     <= scratch_next;
            baud_div_lo <= baud_div_lo_next;
        end
    end

    // -------------------------------------------------------------------------
    // Read Logic
    // -------------------------------------------------------------------------
    always_comb begin
        hrdata_next = '0;
        if (re) begin
            case (ahb.HADDR[7:0])
                8'h04: hrdata_next = int_enable;
                8'h0C: hrdata_next = line_ctrl;
                8'h10: hrdata_next = mode_ctrl;
                8'h14: hrdata_next = line_status;
                8'h1C: hrdata_next = scratch;
                8'h20: hrdata_next = baud_div_lo;
                default: hrdata_next = '0;
            endcase
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ahb.HRDATA <= '0;
        end else begin
            if (re) ahb.HRDATA <= hrdata_next;
        end
    end

    // -------------------------------------------------------------------------
    // UART TX Implementation
    // -------------------------------------------------------------------------
    logic [15:0] baud_cnt;
    logic [3:0]  oversample_cnt;
    logic        baud_clear;
    logic        tx_tick;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_cnt <= '0;
            oversample_cnt <= '0;
        end else if (baud_clear) begin
            baud_cnt <= '0;
            oversample_cnt <= '0;
        end else begin
            if (baud_cnt == baud_div_lo[15:0] - 1) begin
                baud_cnt <= '0;
                oversample_cnt <= oversample_cnt + 1;
            end else begin
                baud_cnt <= baud_cnt + 1;
            end
        end
    end
    
    assign tx_tick = (baud_cnt == baud_div_lo[15:0] - 1) && (oversample_cnt == 4'd15);

    typedef enum logic [2:0] {
        TX_IDLE, TX_START, TX_DATA, TX_STOP
    } tx_state_t;
    
    tx_state_t tx_state, tx_state_next;
    logic [7:0] tx_shift, tx_shift_next;
    logic [2:0] tx_bit_cnt, tx_bit_cnt_next;
    logic       tx_out_reg, tx_out_next;

    always_comb begin
        baud_clear      = 1'b0;
        tx_state_next   = tx_state;
        tx_shift_next   = tx_shift;
        tx_bit_cnt_next = tx_bit_cnt;
        tx_out_next     = tx_out_reg;
        
        case (tx_state)
            TX_IDLE: begin
                tx_out_next = 1'b1;
                if (we && reg_addr == 8'h00) begin
                    tx_shift_next = ahb.HWDATA[7:0];
                    tx_state_next = TX_START;
                    tx_out_next   = 1'b0; // Send start bit
                    baud_clear    = 1'b1;
                end
            end
            TX_START: begin
                if (tx_tick) begin
                    tx_state_next   = TX_DATA;
                    tx_bit_cnt_next = '0;
                    tx_out_next     = tx_shift[0];
                end
            end
            TX_DATA: begin
                if (tx_tick) begin
                    tx_shift_next = {1'b0, tx_shift[7:1]};
                    if (tx_bit_cnt == 3'd7) begin
                        tx_state_next = TX_STOP;
                        tx_out_next   = 1'b1; // Send stop bit
                    end else begin
                        tx_bit_cnt_next = tx_bit_cnt + 1;
                        tx_out_next     = tx_shift[1];
                    end
                end
            end
            TX_STOP: begin
                if (tx_tick) begin
                    tx_state_next = TX_IDLE;
                end
            end
            default: tx_state_next = TX_IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state   <= TX_IDLE;
            tx_shift   <= '0;
            tx_bit_cnt <= '0;
            tx_out_reg <= 1'b1;
        end else begin
            tx_state   <= tx_state_next;
            tx_shift   <= tx_shift_next;
            tx_bit_cnt <= tx_bit_cnt_next;
            tx_out_reg <= tx_out_next;
        end
    end
    
    assign uif.tx = tx_out_reg;

    always_comb begin
        line_status_next = 32'h0;
        line_status_next[5] = (tx_state == TX_IDLE); // THRE
        line_status_next[6] = (tx_state == TX_IDLE); // TEMT
        
        uif.irq = 1'b0;
        uif.rts_n = 1'b1;
    end

endmodule
