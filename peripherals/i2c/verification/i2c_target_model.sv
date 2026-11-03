`ifndef I2C_TARGET_MODEL_SV
`define I2C_TARGET_MODEL_SV

module i2c_target_model #(
    parameter bit [6:0] TARGET_ADDR = 7'h5A
)(
    input  logic scl_in,    // SCL line state (from bus)
    input  logic sda_in,    // SDA line state (from bus)
    output logic scl_oe,    // Target pulls SCL low
    output logic sda_oe,    // Target pulls SDA low
    
    // Configuration
    input  logic [3:0]  stretch_cycles,
    input  logic        force_nack,
    input  logic [7:0]  read_data
);

    typedef enum logic [3:0] {
        IDLE,
        START_DETECTED,
        ADDR_SHIFT,
        ADDR_ACK,
        TX_DATA,
        TX_ACK,
        RX_DATA,
        RX_ACK
    } state_t;

    state_t state = IDLE;
    logic [7:0] shift_reg;
    logic [3:0] bit_cnt;
    logic [7:0] stretch_cnt;
    
    logic scl_fall, scl_rise;
    logic sda_fall, sda_rise;
    logic last_scl, last_sda;

    always @(scl_in or sda_in) begin
        scl_fall = last_scl & ~scl_in;
        scl_rise = ~last_scl & scl_in;
        sda_fall = last_sda & ~sda_in;
        sda_rise = ~last_sda & sda_in;

        // Start condition: SDA falls while SCL is high
        if (scl_in && sda_fall) begin
            state = START_DETECTED;
            bit_cnt = 0;
            stretch_cnt = stretch_cycles;
            scl_oe = 0;
            sda_oe = 0;
        end
        // Stop condition: SDA rises while SCL is high
        else if (scl_in && sda_rise) begin
            state = IDLE;
            scl_oe = 0;
            sda_oe = 0;
        end
        else begin
            case (state)
                START_DETECTED: begin
                    if (scl_fall) begin
                        state = ADDR_SHIFT;
                        bit_cnt = 0;
                    end
                end
                
                ADDR_SHIFT: begin
                    if (scl_rise) begin
                        shift_reg = {shift_reg[6:0], sda_in};
                        bit_cnt = bit_cnt + 1;
                    end
                    else if (scl_fall && bit_cnt == 8) begin
                        if (shift_reg[7:1] == TARGET_ADDR) begin
                            state = ADDR_ACK;
                            sda_oe = ~force_nack; // ACK if not forced NACK
                        end else begin
                            state = IDLE; // Not our address
                        end
                        stretch_cnt = stretch_cycles;
                    end
                end

                ADDR_ACK: begin
                    // Clock stretching at the ACK bit
                    if (!scl_in && stretch_cnt > 0) begin
                        scl_oe = 1; // Pull SCL low to stretch
                        stretch_cnt = stretch_cnt - 1;
                    end else begin
                        scl_oe = 0;
                    end

                    if (scl_fall) begin
                        sda_oe = 0;
                        if (shift_reg[0]) begin // READ
                            state = TX_DATA;
                            shift_reg = read_data;
                        end else begin
                            state = RX_DATA;
                        end
                        bit_cnt = 0;
                    end
                end

                RX_DATA: begin
                    if (scl_rise) begin
                        shift_reg = {shift_reg[6:0], sda_in};
                        bit_cnt = bit_cnt + 1;
                    end
                    else if (scl_fall && bit_cnt == 8) begin
                        state = RX_ACK;
                        sda_oe = ~force_nack;
                        stretch_cnt = stretch_cycles;
                    end
                end

                RX_ACK: begin
                    if (!scl_in && stretch_cnt > 0) begin
                        scl_oe = 1;
                        stretch_cnt = stretch_cnt - 1;
                    end else begin
                        scl_oe = 0;
                    end

                    if (scl_fall) begin
                        sda_oe = 0;
                        state = RX_DATA;
                        bit_cnt = 0;
                    end
                end

                TX_DATA: begin
                    if (!scl_in) begin
                        sda_oe = ~shift_reg[7]; // Drive bit (assuming pullup, so inverted if we want 1 we don't pull)
                    end
                    if (scl_fall) begin
                        shift_reg = {shift_reg[6:0], 1'b0};
                        bit_cnt = bit_cnt + 1;
                        if (bit_cnt == 8) begin
                            state = TX_ACK;
                            sda_oe = 0;
                        end
                    end
                end

                TX_ACK: begin
                    // Read NACK/ACK from master on scl_rise (not done here directly, wait for fall)
                    if (scl_fall) begin
                        // If NACK, master should issue STOP or Repeated START
                        // We go back to IDLE unless repeated start
                        state = TX_DATA;
                        bit_cnt = 0;
                        shift_reg = read_data; // Next byte
                    end
                end
            endcase
        end
        
        last_scl <= scl_in;
        last_sda <= sda_in;
    end

    initial begin
        scl_oe = 0;
        sda_oe = 0;
        last_scl = 1;
        last_sda = 1;
    end

endmodule

`endif
