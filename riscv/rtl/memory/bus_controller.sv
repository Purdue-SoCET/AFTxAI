`timescale 1ns/1ps

module bus_controller #(
    parameter int BLOCK_SIZE = 4
)(
    input  logic HCLK,
    input  logic nRST,

    // Interface from iCache
    cache_bus_if.bus_ctrl icache_if,

    // Interface from dCache
    cache_bus_if.bus_ctrl dcache_if,

    // Interface to External AHB Manager
    bus_ahbm_if.manager ahbm_if
);

    typedef enum logic {
        STATE_IDLE,
        STATE_XFER
    } state_e;

    state_e state_q;
    logic active_sel_q; // 0 for iCache, 1 for dCache
    logic [3:0] word_cnt_q;

    // Error Halt State
    logic halt_error_q;

    always_ff @(posedge HCLK or negedge nRST) begin
        if (!nRST) begin
            halt_error_q <= 1'b0;
        end else if (ahbm_if.error) begin
            halt_error_q <= 1'b1;
        end
    end

    // --- Internal combinational routing ---
    logic active_req;
    logic active_rnw;
    logic [31:0] active_addr;
    logic [31:0] active_wdata;

    assign active_req = active_sel_q ? dcache_if.req : icache_if.req;
    assign active_rnw = active_sel_q ? dcache_if.rnw : icache_if.rnw;
    assign active_addr = active_sel_q ? dcache_if.addr : icache_if.addr;
    assign active_wdata = active_sel_q ? dcache_if.wdata : icache_if.wdata;

    // --- FSM ---
    always_ff @(posedge HCLK or negedge nRST) begin
        if (!nRST) begin
            state_q <= STATE_IDLE;
            active_sel_q <= 1'b0;
            word_cnt_q <= '0;
        end else begin
            case (state_q)
                STATE_IDLE: begin
                    // Fixed Arbitration: dCache > iCache
                    if (dcache_if.req) begin
                        active_sel_q <= 1'b1;
                        state_q <= STATE_XFER;
                        word_cnt_q <= '0;
                    end else if (icache_if.req) begin
                        active_sel_q <= 1'b0;
                        state_q <= STATE_XFER;
                        word_cnt_q <= '0;
                    end
                end
                STATE_XFER: begin
                    if (ahbm_if.ack) begin
                        if (word_cnt_q == BLOCK_SIZE - 1) begin
                            state_q <= STATE_IDLE;
                        end else begin
                            word_cnt_q <= word_cnt_q + 1;
                        end
                    end
                end
            endcase
        end
    end

    // --- Outputs ---
    always_comb begin
        // Default Cache Outputs
        icache_if.gnt = 1'b0;
        icache_if.valid = 1'b0;
        icache_if.last = 1'b0;
        icache_if.rdata = ahbm_if.rdata;
        icache_if.error = halt_error_q;

        dcache_if.gnt = 1'b0;
        dcache_if.valid = 1'b0;
        dcache_if.last = 1'b0;
        dcache_if.rdata = ahbm_if.rdata;
        dcache_if.error = halt_error_q;

        // Default AHB Manager Outputs
        ahbm_if.req = 1'b0;
        ahbm_if.addr = 32'b0;
        ahbm_if.rnw = 1'b0;
        ahbm_if.size = 3'b010; // 32-bit (word) size
        ahbm_if.wdata = 32'b0;

        case (state_q)
            STATE_IDLE: begin
                // Drive grants
                if (dcache_if.req) begin
                    dcache_if.gnt = 1'b1;
                end else if (icache_if.req) begin
                    icache_if.gnt = 1'b1;
                end
            end
            STATE_XFER: begin
                ahbm_if.req = 1'b1;
                ahbm_if.rnw = active_rnw;
                // Add word_cnt * 4 to base address
                ahbm_if.addr = active_addr + (word_cnt_q << 2);
                ahbm_if.wdata = active_wdata;

                if (ahbm_if.ack) begin
                    if (active_sel_q == 1'b1) begin
                        dcache_if.valid = 1'b1;
                        dcache_if.last = (word_cnt_q == BLOCK_SIZE - 1);
                    end else begin
                        icache_if.valid = 1'b1;
                        icache_if.last = (word_cnt_q == BLOCK_SIZE - 1);
                    end
                end
            end
        endcase
    end

endmodule
