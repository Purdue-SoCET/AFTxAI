`timescale 1ns/1ps
module bus_controller #(parameter int BLOCK_SIZE = 4) (
    input logic HCLK, input logic nRST,
    cache_bus_if.bus_ctrl icache_if,
    cache_bus_if.bus_ctrl dcache_if,
    bus_ahbm_if.manager ahbm_if,
    bus_controller_if.mp port_unused
);
    typedef enum logic { STATE_IDLE, STATE_XFER } state_e;
    state_e state, next_state;
    logic active_sel, next_active_sel;
    logic [3:0] word_cnt, next_word_cnt;
    logic halt_error, next_halt_error;

    logic active_req, active_rnw;
    logic [31:0] active_addr, active_wdata;
    assign active_req = active_sel ? dcache_if.req : icache_if.req;
    assign active_rnw = active_sel ? dcache_if.rnw : icache_if.rnw;
    assign active_addr = active_sel ? dcache_if.addr : icache_if.addr;
    assign active_wdata = active_sel ? dcache_if.wdata : icache_if.wdata;

    always_comb begin
        next_state = state;
        next_active_sel = active_sel;
        next_word_cnt = word_cnt;
        next_halt_error = ahbm_if.error ? 1'b1 : halt_error;
        
        case (state)
            STATE_IDLE: begin
                if (dcache_if.req) begin next_active_sel = 1'b1; next_state = STATE_XFER; next_word_cnt = '0; end
                else if (icache_if.req) begin next_active_sel = 1'b0; next_state = STATE_XFER; next_word_cnt = '0; end
            end
            STATE_XFER: begin
                if (ahbm_if.ack) begin
                    if (word_cnt == BLOCK_SIZE - 1) next_state = STATE_IDLE;
                    else next_word_cnt = word_cnt + 1;
                end
            end
        endcase
    end

    always_ff @(posedge HCLK or negedge nRST) begin
        if (!nRST) begin
            state <= STATE_IDLE;
            active_sel <= 1'b0;
            word_cnt <= '0;
            halt_error <= 1'b0;
        end else begin
            state <= next_state;
            active_sel <= next_active_sel;
            word_cnt <= next_word_cnt;
            halt_error <= next_halt_error;
        end
    end

    always_comb begin
        icache_if.gnt = 1'b0; icache_if.valid = 1'b0; icache_if.last = 1'b0; icache_if.rdata = ahbm_if.rdata; icache_if.error = halt_error;
        dcache_if.gnt = 1'b0; dcache_if.valid = 1'b0; dcache_if.last = 1'b0; dcache_if.rdata = ahbm_if.rdata; dcache_if.error = halt_error;
        ahbm_if.req = 1'b0; ahbm_if.addr = 32'b0; ahbm_if.rnw = 1'b0; ahbm_if.size = 3'b010; ahbm_if.wdata = 32'b0;

        case (state)
            STATE_IDLE: begin
                if (dcache_if.req) dcache_if.gnt = 1'b1;
                else if (icache_if.req) icache_if.gnt = 1'b1;
            end
            STATE_XFER: begin
                ahbm_if.req = 1'b1; ahbm_if.rnw = active_rnw; ahbm_if.addr = active_addr + (word_cnt << 2); ahbm_if.wdata = active_wdata;
                if (ahbm_if.ack) begin
                    if (active_sel) begin dcache_if.valid = 1'b1; dcache_if.last = (word_cnt == BLOCK_SIZE - 1); end
                    else begin icache_if.valid = 1'b1; icache_if.last = (word_cnt == BLOCK_SIZE - 1); end
                end
            end
        endcase
    end
endmodule
