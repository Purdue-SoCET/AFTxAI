module i2c_engine (
    input  logic        PCLK,
    input  logic        PRESETn,
    
    // Commands
    input  logic        cmd_valid,
    input  logic        cmd_start,
    input  logic        cmd_stop,
    input  logic        cmd_write,
    input  logic        cmd_read,
    input  logic        cmd_nack,
    input  logic [7:0]  tx_data,
    input  logic [15:0] prescale,
    input  logic        enable,
    
    // Status
    output logic        tip,
    output logic        bus_busy,
    output logic        rx_nack,
    output logic [7:0]  rx_data,
    
    // I2C physical
    output logic        scl_o,
    output logic        scl_oe,
    input  logic        scl_i,
    output logic        sda_o,
    output logic        sda_oe,
    input  logic        sda_i
);

    assign scl_o = 1'b0;
    assign sda_o = 1'b0;

    typedef enum logic [4:0] {
        ST_IDLE,
        ST_START_0, ST_START_1, ST_START_2, ST_START_3,
        ST_BIT_0,   ST_BIT_1,   ST_BIT_2,   ST_BIT_3,
        ST_ACK_0,   ST_ACK_1,   ST_ACK_2,   ST_ACK_3,
        ST_STOP_0,  ST_STOP_1,  ST_STOP_2,  ST_STOP_3,
        ST_DONE
    } state_t;

    state_t state, state_next;
    
    logic [15:0] clk_cnt, clk_cnt_next;
    logic        tick;
    logic        stretch_wait;

    logic        do_stop, do_write, do_read, do_nack;
    logic        do_stop_next, do_write_next, do_read_next, do_nack_next;
    logic [7:0]  tx_shift, tx_shift_next;
    logic [7:0]  rx_shift, rx_shift_next;
    logic [2:0]  bit_cnt, bit_cnt_next;
    
    logic scl_oe_next, sda_oe_next, bus_busy_next, tip_next, rx_nack_next;
    logic [7:0] rx_data_next;

    // Clock stretching logic
    // Wait until scl_i is 1 when scl_oe is 0
    assign stretch_wait = !scl_oe && !scl_i;

    always_comb begin
        clk_cnt_next = clk_cnt;
        if (state == ST_IDLE || state == ST_DONE || !enable) begin
            clk_cnt_next = 16'h0;
        end else begin
            if (stretch_wait) begin
                clk_cnt_next = 16'h0;
            end else if (clk_cnt == prescale) begin
                clk_cnt_next = 16'h0;
            end else begin
                clk_cnt_next = clk_cnt + 1'b1;
            end
        end
    end
    assign tick = (clk_cnt == prescale) && !stretch_wait;

    always_comb begin
        state_next    = state;
        scl_oe_next   = scl_oe;
        sda_oe_next   = sda_oe;
        bus_busy_next = bus_busy;
        tip_next      = tip;
        rx_nack_next  = rx_nack;
        rx_data_next  = rx_data;
        bit_cnt_next  = bit_cnt;
        do_write_next = do_write;
        do_read_next  = do_read;
        do_stop_next  = do_stop;
        do_nack_next  = do_nack;
        tx_shift_next = tx_shift;
        rx_shift_next = rx_shift;

        if (!enable) begin
            state_next    = ST_IDLE;
            scl_oe_next   = 1'b0;
            sda_oe_next   = 1'b0;
            bus_busy_next = 1'b0;
            tip_next      = 1'b0;
        end else begin
            if (state == ST_IDLE) begin
                if (cmd_valid) begin
                    tip_next      = 1'b1;
                    do_write_next = cmd_write;
                    do_read_next  = cmd_read;
                    do_stop_next  = cmd_stop;
                    do_nack_next  = cmd_nack;
                    tx_shift_next = tx_data;
                    bit_cnt_next  = 3'd7;

                    if (cmd_start) begin
                        state_next = ST_START_0;
                    end else if (cmd_write || cmd_read) begin
                        state_next  = ST_BIT_0;
                        scl_oe_next = 1'b1; // Ensure SCL is pulled low
                        if (cmd_write) sda_oe_next = ~tx_data[7];
                        else sda_oe_next = 1'b0;
                    end else if (cmd_stop) begin
                        state_next  = ST_STOP_0;
                        scl_oe_next = 1'b1;
                        sda_oe_next = 1'b1; // Pull SDA low for STOP prep
                    end else begin
                        state_next = ST_DONE;
                    end
                end
            end else if (state == ST_DONE) begin
                tip_next   = 1'b0;
                state_next = ST_IDLE;
            end else if (tick) begin
                case (state)
                    // START
                    ST_START_0: begin
                        state_next = ST_START_1;
                        if (bus_busy) begin
                            scl_oe_next = 1'b1; // Hold SCL low
                            sda_oe_next = 1'b0; // Release SDA
                        end else begin
                            scl_oe_next = 1'b0;
                            sda_oe_next = 1'b0;
                        end
                    end
                    ST_START_1: begin
                        state_next = ST_START_2;
                        scl_oe_next = 1'b0; // Release SCL
                    end
                    ST_START_2: begin
                        state_next    = ST_START_3;
                        sda_oe_next   = 1'b1; // Pull SDA low -> START
                        bus_busy_next = 1'b1;
                    end
                    ST_START_3: begin
                        if (do_write || do_read) state_next = ST_BIT_0;
                        else if (do_stop) state_next = ST_STOP_0;
                        else state_next = ST_DONE;
                        
                        scl_oe_next = 1'b1; // Pull SCL low
                        if (do_write || do_read) begin
                            if (do_write) sda_oe_next = ~tx_shift[7];
                            else sda_oe_next = 1'b0;
                        end else if (do_stop) begin
                            sda_oe_next = 1'b1;
                        end else begin
                            sda_oe_next = 1'b0;
                        end
                    end

                    // BIT
                    ST_BIT_0: begin
                        state_next = ST_BIT_1;
                    end
                    ST_BIT_1: begin
                        state_next  = ST_BIT_2;
                        scl_oe_next = 1'b0; // Release SCL -> goes high
                    end
                    ST_BIT_2: begin
                        state_next = ST_BIT_3;
                        if (do_read) begin
                            rx_shift_next = {rx_shift[6:0], scl_i ? sda_i : sda_i}; // Sample in middle of high phase
                        end
                    end
                    ST_BIT_3: begin
                        scl_oe_next = 1'b1; // Pull SCL low
                        if (bit_cnt == 0) begin
                            state_next = ST_ACK_0;
                            if (do_write) sda_oe_next = 1'b0; 
                            else sda_oe_next = do_nack;       
                        end else begin
                            state_next = ST_BIT_0;
                            bit_cnt_next = bit_cnt - 3'd1;
                            if (do_write) begin
                                sda_oe_next = ~tx_shift[6];
                                tx_shift_next = {tx_shift[6:0], 1'b0};
                            end
                        end
                    end

                    // ACK
                    ST_ACK_0: begin
                        state_next = ST_ACK_1;
                    end
                    ST_ACK_1: begin
                        state_next  = ST_ACK_2;
                        scl_oe_next = 1'b0; // Release SCL
                    end
                    ST_ACK_2: begin
                        state_next = ST_ACK_3;
                        if (do_write) begin
                            rx_nack_next = sda_i; // Sample ACK
                        end
                    end
                    ST_ACK_3: begin
                        if (do_stop) begin
                            state_next  = ST_STOP_0;
                            scl_oe_next = 1'b1; // Pull SCL low
                            sda_oe_next = 1'b1; // Pull SDA low for STOP prep
                        end else begin
                            state_next  = ST_DONE;
                            scl_oe_next = 1'b1; // Hold SCL low for next command
                        end
                        if (do_read) begin
                            rx_data_next = rx_shift;
                        end
                    end

                    // STOP
                    ST_STOP_0: begin
                        state_next = ST_STOP_1;
                        // SCL is low, SDA is low
                    end
                    ST_STOP_1: begin
                        state_next  = ST_STOP_2;
                        scl_oe_next = 1'b0; // Release SCL
                    end
                    ST_STOP_2: begin
                        state_next    = ST_STOP_3;
                        sda_oe_next   = 1'b0; // Release SDA -> STOP condition
                        bus_busy_next = 1'b0;
                    end
                    ST_STOP_3: begin
                        state_next = ST_DONE;
                    end

                    default: state_next = ST_IDLE;
                endcase
            end
        end
    end

    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            clk_cnt  <= 16'h0;
            state    <= ST_IDLE;
            scl_oe   <= 1'b0;
            sda_oe   <= 1'b0;
            bus_busy <= 1'b0;
            tip      <= 1'b0;
            rx_nack  <= 1'b0;
            rx_data  <= 8'h0;
            bit_cnt  <= 3'd0;
            do_write <= 1'b0;
            do_read  <= 1'b0;
            do_stop  <= 1'b0;
            do_nack  <= 1'b0;
            tx_shift <= 8'h0;
            rx_shift <= 8'h0;
        end else begin
            clk_cnt  <= clk_cnt_next;
            state    <= state_next;
            scl_oe   <= scl_oe_next;
            sda_oe   <= sda_oe_next;
            bus_busy <= bus_busy_next;
            tip      <= tip_next;
            rx_nack  <= rx_nack_next;
            rx_data  <= rx_data_next;
            bit_cnt  <= bit_cnt_next;
            do_write <= do_write_next;
            do_read  <= do_read_next;
            do_stop  <= do_stop_next;
            do_nack  <= do_nack_next;
            tx_shift <= tx_shift_next;
            rx_shift <= rx_shift_next;
        end
    end

endmodule
