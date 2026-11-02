module sram_controller #(
    parameter int ADDR_WIDTH = 19,
    parameter int WAIT_CYCLES = 2
)(
    input logic HCLK,
    input logic nRST,

    bus_protocol_if.peripheral_vital bus,
    sram_if.controller sram
);

    typedef enum logic [3:0] {
        IDLE,
        A1_SETUP,
        A1_ACTIVE,
        A1_HOLD,
        A2_SETUP,
        A2_ACTIVE,
        A2_HOLD
    } state_t;

    state_t state_d, state_q;

    logic [15:0] holding_reg_d, holding_reg_q;
    logic [15:0] holding_reg2_d, holding_reg2_q;

    // Counter signals
    logic counter_clear;
    logic counter_enable;
    logic counter_overflow;

    // WAIT_CYCLES handling
    localparam int NBITS = $clog2(WAIT_CYCLES > 0 ? WAIT_CYCLES + 1 : 2);
    logic [NBITS-1:0] overflow_val;
    assign overflow_val = NBITS'(WAIT_CYCLES > 0 ? WAIT_CYCLES - 1 : 0);

    counter #(
        .NBITS(NBITS)
    ) wait_counter (
        .CLK(HCLK),
        .nRST(nRST),
        .clear(counter_clear),
        .count_enable(counter_enable),
        .overflow_val(overflow_val),
        /* verilator lint_off PINCONNECTEMPTY */
        .count_out(),
        /* verilator lint_on PINCONNECTEMPTY */
        .overflow_flag(counter_overflow)
    );

    logic active_done;
    assign active_done = (WAIT_CYCLES == 0) ? 1'b1 : counter_overflow;

    // Helpers
    logic need_a1, need_a2;
    assign need_a1 = |bus.strobe[1:0];
    assign need_a2 = |bus.strobe[3:2];

    logic is_last_cycle;
    always_comb begin
        is_last_cycle = 1'b0;
        if (state_q == A1_HOLD && !need_a2) is_last_cycle = 1'b1;
        if (state_q == A2_HOLD) is_last_cycle = 1'b1;
        if (state_q == IDLE && (bus.wen | bus.ren) && !need_a1 && !need_a2) is_last_cycle = 1'b1;
    end

    assign bus.request_stall = (bus.wen | bus.ren) & ~is_last_cycle;
    assign bus.error = 1'b0;

    // Holding register for read data
    always_comb begin
        holding_reg_d = holding_reg_q;
        holding_reg2_d = holding_reg2_q;
        // Sample A1 data at the end of A1_ACTIVE (when transitioning to A1_HOLD)
        if (state_q == A1_ACTIVE && active_done && bus.ren) begin
            holding_reg_d = sram.rdata;
        end
        // Sample A2 data at the end of A2_ACTIVE
        if (state_q == A2_ACTIVE && active_done && bus.ren) begin
            holding_reg2_d = sram.rdata;
        end
    end

    // rdata is composed of holding register (lower 16) and upper 16
    assign bus.rdata = { (need_a2 ? holding_reg2_q : 16'h0000), (need_a1 ? holding_reg_q : 16'h0000) };

    // FSM
    always_comb begin
        state_d = state_q;
        counter_clear = 1'b0;
        counter_enable = 1'b0;

        case (state_q)
            IDLE: begin
                if (bus.wen | bus.ren) begin
                    if (need_a1) begin
                        state_d = A1_SETUP;
                    end else if (need_a2) begin
                        state_d = A2_SETUP;
                    end
                end
            end

            A1_SETUP: begin
                state_d = A1_ACTIVE;
            end

            A1_ACTIVE: begin
                counter_enable = 1'b1;
                if (active_done) begin
                    state_d = A1_HOLD;
                end
            end

            A1_HOLD: begin
                if (need_a2) begin
                    state_d = A2_SETUP;
                end else begin
                    state_d = IDLE;
                end
            end

            A2_SETUP: begin
                state_d = A2_ACTIVE;
            end

            A2_ACTIVE: begin
                counter_enable = 1'b1;
                if (active_done) begin
                    state_d = A2_HOLD;
                end
            end

            A2_HOLD: begin
                state_d = IDLE;
            end
            
            default: state_d = IDLE;
        endcase

        // Clear counter synchronously before it's used in ACTIVE states
        if (state_q == IDLE || state_q == A1_HOLD) begin
            counter_clear = 1'b1;
        end
    end

    assign sram.addr = bus.addr[ADDR_WIDTH+1 : 2];
    assign sram.pad_oe = bus.ren;

    logic ce0_n, oe0_n, we0_n, ub0_n, lb0_n;
    logic ce1_n, oe1_n, we1_n, ub1_n, lb1_n;
    logic [15:0] wdata;

    always_comb begin
        ce0_n = 1'b1; oe0_n = 1'b1; we0_n = 1'b1; ub0_n = 1'b1; lb0_n = 1'b1;
        ce1_n = 1'b1; oe1_n = 1'b1; we1_n = 1'b1; ub1_n = 1'b1; lb1_n = 1'b1;
        wdata = 16'h0000;

        case (state_q)
            A1_SETUP, A1_ACTIVE, A1_HOLD: begin
                ce0_n = 1'b0;
                ub0_n = ~bus.strobe[1];
                lb0_n = ~bus.strobe[0];
                wdata = bus.wdata[15:0];
                if (state_q == A1_ACTIVE) begin
                    if (bus.wen) we0_n = 1'b0;
                    if (bus.ren) oe0_n = 1'b0;
                end
            end

            A2_SETUP, A2_ACTIVE, A2_HOLD: begin
                ce1_n = 1'b0;
                ub1_n = ~bus.strobe[3];
                lb1_n = ~bus.strobe[2];
                wdata = bus.wdata[31:16];
                if (state_q == A2_ACTIVE) begin
                    if (bus.wen) we1_n = 1'b0;
                    if (bus.ren) oe1_n = 1'b0;
                end
            end
            default: ;
        endcase
    end

    assign sram.ce0_n = ce0_n;
    assign sram.oe0_n = oe0_n;
    assign sram.we0_n = we0_n;
    assign sram.ub0_n = ub0_n;
    assign sram.lb0_n = lb0_n;

    assign sram.ce1_n = ce1_n;
    assign sram.oe1_n = oe1_n;
    assign sram.we1_n = we1_n;
    assign sram.ub1_n = ub1_n;
    assign sram.lb1_n = lb1_n;

    assign sram.wdata = wdata;

    always_ff @(posedge HCLK or negedge nRST) begin
        if (!nRST) begin
            state_q <= IDLE;
            holding_reg_q <= '0;
            holding_reg2_q <= '0;
        end else begin
            state_q <= state_d;
            holding_reg_q <= holding_reg_d;
            holding_reg2_q <= holding_reg2_d;
        end
    end

endmodule
