`timescale 1ns/1ps

module uart_tx (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       baud_tick,   // 1 tick per bit
    input  logic [7:0] tx_data,
    input  logic       tx_valid,
    output logic       tx_ready,
    output logic       tx_out
);
    typedef enum logic [2:0] {
        IDLE,
        START,
        DATA,
        STOP
    } state_t;

    state_t state_q, state_d;
    logic [7:0] shift_reg_q, shift_reg_d;
    logic [2:0] bit_cnt_q, bit_cnt_d;
    logic tx_q, tx_d;

    assign tx_out = tx_q;
    assign tx_ready = (state_q == IDLE);

    always_comb begin
        state_d     = state_q;
        shift_reg_d = shift_reg_q;
        bit_cnt_d   = bit_cnt_q;
        tx_d        = tx_q;

        case (state_q)
            IDLE: begin
                tx_d = 1'b1;
                if (tx_valid) begin
                    shift_reg_d = tx_data;
                    state_d     = START;
                end
            end
            START: begin
                if (baud_tick) begin
                    tx_d    = 1'b0; // Start bit
                    state_d = DATA;
                    bit_cnt_d = '0;
                end
            end
            DATA: begin
                if (baud_tick) begin
                    tx_d        = shift_reg_q[0];
                    shift_reg_d = {1'b0, shift_reg_q[7:1]};
                    if (bit_cnt_q == 3'd7) begin
                        state_d = STOP;
                    end else begin
                        bit_cnt_d = bit_cnt_q + 1;
                    end
                end
            end
            STOP: begin
                if (baud_tick) begin
                    tx_d    = 1'b1; // Stop bit
                    state_d = IDLE;
                end
            end
            default: state_d = IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q     <= IDLE;
            shift_reg_q <= '0;
            bit_cnt_q   <= '0;
            tx_q        <= 1'b1;
        end else begin
            state_q     <= state_d;
            shift_reg_q <= shift_reg_d;
            bit_cnt_q   <= bit_cnt_d;
            tx_q        <= tx_d;
        end
    end
endmodule
