`timescale 1ns/1ps

module uart_rx #(
    parameter OVERSAMPLE = 16
)(
    input  logic       clk,
    input  logic       rst_n,
    input  logic       os_tick,   // Oversample tick
    input  logic       rx_in,
    output logic [7:0] rx_data,
    output logic       rx_valid
);
    typedef enum logic [2:0] {
        IDLE,
        START,
        DATA,
        STOP
    } state_t;

    state_t state_q, state_d;
    logic [7:0] shift_reg_q, shift_reg_d;
    logic [3:0] os_cnt_q, os_cnt_d;
    logic [2:0] bit_cnt_q, bit_cnt_d;
    logic       rx_valid_q, rx_valid_d;

    // Double-flop synchronizer for RX
    logic rx_sync1_q, rx_sync1_d;
    logic rx_sync2_q, rx_sync2_d;

    assign rx_data  = shift_reg_q;
    assign rx_valid = rx_valid_q;

    localparam HALF_BIT = OVERSAMPLE / 2;
    localparam FULL_BIT = OVERSAMPLE - 1;

    always_comb begin
        state_d     = state_q;
        shift_reg_d = shift_reg_q;
        os_cnt_d    = os_cnt_q;
        bit_cnt_d   = bit_cnt_q;
        rx_valid_d  = 1'b0; // Default to 0 (pulse)

        rx_sync1_d  = rx_in;
        rx_sync2_d  = rx_sync1_q;

        if (os_tick) begin
            case (state_q)
                IDLE: begin
                    if (rx_sync2_q == 1'b0) begin // Start bit edge detected
                        state_d  = START;
                        os_cnt_d = 4'd1;
                    end
                end
                START: begin
                    if (os_cnt_q == HALF_BIT) begin
                        if (rx_sync2_q == 1'b0) begin // Confirm start bit
                            os_cnt_d = 4'd0;
                            state_d  = DATA;
                            bit_cnt_d = '0;
                        end else begin
                            state_d = IDLE; // Glitch
                        end
                    end else begin
                        os_cnt_d = os_cnt_q + 1;
                    end
                end
                DATA: begin
                    if (os_cnt_q == FULL_BIT) begin
                        os_cnt_d = 4'd0;
                        shift_reg_d = {rx_sync2_q, shift_reg_q[7:1]};
                        if (bit_cnt_q == 3'd7) begin
                            state_d = STOP;
                        end else begin
                            bit_cnt_d = bit_cnt_q + 1;
                        end
                    end else begin
                        os_cnt_d = os_cnt_q + 1;
                    end
                end
                STOP: begin
                    if (os_cnt_q == FULL_BIT) begin
                        rx_valid_d = 1'b1;
                        state_d    = IDLE; // Wait for next start bit
                    end else begin
                        os_cnt_d = os_cnt_q + 1;
                    end
                end
                default: state_d = IDLE;
            endcase
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q     <= IDLE;
            shift_reg_q <= '0;
            os_cnt_q    <= '0;
            bit_cnt_q   <= '0;
            rx_valid_q  <= '0;
            rx_sync1_q  <= 1'b1;
            rx_sync2_q  <= 1'b1;
        end else begin
            state_q     <= state_d;
            shift_reg_q <= shift_reg_d;
            os_cnt_q    <= os_cnt_d;
            bit_cnt_q   <= bit_cnt_d;
            rx_valid_q  <= rx_valid_d;
            rx_sync1_q  <= rx_sync1_d;
            rx_sync2_q  <= rx_sync2_d;
        end
    end
endmodule
