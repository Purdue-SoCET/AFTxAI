`timescale 1ns/1ps
module bus_controller #(parameter int BLOCK_SIZE = 4) (
    input logic HCLK, input logic nRST,
    cache_bus_if.bus_ctrl icache_if,
    cache_bus_if.bus_ctrl dcache_if,
    cpu_cache_if.cache uncached_if,
    input logic dcache_advance,
    bus_ahbm_if.manager ahbm_if,
    bus_controller_if.mp port_unused
);
    typedef enum logic [1:0] { STATE_IDLE, STATE_XFER, STATE_UNCACHED } state_e;
    state_e state, next_state;
    logic active_sel, next_active_sel; // 0=icache, 1=dcache
    logic active_rnw_reg, next_active_rnw_reg;
    logic [31:0] active_addr_reg, next_active_addr_reg;
    logic [3:0] word_cnt, next_word_cnt;
    logic halt_error, next_halt_error;

    logic active_req, active_rnw;
    logic [31:0] active_addr, active_wdata;
    assign active_req = active_sel ? dcache_if.req : icache_if.req;
    assign active_rnw = active_sel ? dcache_if.rnw : icache_if.rnw;
    assign active_addr = active_sel ? dcache_if.addr : icache_if.addr;
    assign active_wdata = active_sel ? dcache_if.wdata : icache_if.wdata;

    logic uncached_rnw_reg, next_uncached_rnw_reg;
    logic [31:0] uncached_wdata_reg, next_uncached_wdata_reg;
    logic [31:0] uncached_rdata_reg, next_uncached_rdata_reg;
    logic [3:0] uncached_wstrb_reg, next_uncached_wstrb_reg;
    logic [2:0] uncached_size_reg, next_uncached_size_reg;
    logic uncached_done_reg, next_uncached_done_reg;

    always_comb begin
        next_state = state;
        next_active_sel = active_sel;
        next_active_rnw_reg = active_rnw_reg;
        next_active_addr_reg = active_addr_reg;
        next_word_cnt = word_cnt;
        next_halt_error = 1'b0; // ahbm_if.error ? 1'b1 : halt_error;
        
        next_uncached_rnw_reg = uncached_rnw_reg;
        next_uncached_wdata_reg = uncached_wdata_reg;
        next_uncached_rdata_reg = uncached_rdata_reg;
        next_uncached_wstrb_reg = uncached_wstrb_reg;
        next_uncached_size_reg = uncached_size_reg;
        next_uncached_done_reg = uncached_done_reg;
        
        if (uncached_if.valid && uncached_if.ready && dcache_advance) begin
            next_uncached_done_reg = 1'b0;
        end
        
        if (!uncached_if.valid) begin
            next_uncached_done_reg = 1'b0;
        end
        
        case (state)
            STATE_IDLE: begin
                if (uncached_if.valid && !uncached_done_reg) begin
                    next_active_addr_reg = uncached_if.addr;
                    next_uncached_rnw_reg = (uncached_if.wstrb == 4'b0);
                    next_uncached_wdata_reg = uncached_if.wdata;
                    next_uncached_wstrb_reg = uncached_if.wstrb;
                    if (uncached_if.wstrb == 4'b1111 || uncached_if.wstrb == 4'b0000)
                        next_uncached_size_reg = 3'b010; // Word
                    else if (uncached_if.wstrb == 4'b0011 || uncached_if.wstrb == 4'b1100)
                        next_uncached_size_reg = 3'b001; // Halfword
                    else
                        next_uncached_size_reg = 3'b000; // Byte
                    next_state = STATE_UNCACHED;
                end
                else if (dcache_if.req) begin 
                    next_active_sel = 1'b1; 
                    next_active_rnw_reg = dcache_if.rnw;
                    next_active_addr_reg = dcache_if.addr;
                    next_state = STATE_XFER; 
                    next_word_cnt = '0; 
                end
                else if (icache_if.req) begin 
                    next_active_sel = 1'b0; 
                    next_active_rnw_reg = icache_if.rnw;
                    next_active_addr_reg = icache_if.addr;
                    next_state = STATE_XFER; 
                    next_word_cnt = '0; 
                end
            end
            STATE_XFER: begin
                if (ahbm_if.ack) begin
                    if (word_cnt == 4'(BLOCK_SIZE - 1)) next_state = STATE_IDLE;
                    else next_word_cnt = word_cnt + 1;
                end
            end
            STATE_UNCACHED: begin
                if (ahbm_if.ack) begin
                    next_uncached_rdata_reg = ahbm_if.rdata;
                    next_uncached_done_reg = 1'b1;
                    next_state = STATE_IDLE;
                end
            end
        endcase
    end

    always_ff @(posedge HCLK or negedge nRST) begin
        if (!nRST) begin
            state <= STATE_IDLE;
            active_sel <= 1'b0;
            active_rnw_reg <= 1'b0;
            active_addr_reg <= 32'b0;
            word_cnt <= '0;
            halt_error <= 1'b0;
            uncached_rnw_reg <= 1'b0;
            uncached_wdata_reg <= 32'b0;
            uncached_rdata_reg <= 32'b0;
            uncached_wstrb_reg <= 4'b0;
            uncached_size_reg <= 3'b010;
            uncached_done_reg <= 1'b0;
        end else begin
            state <= next_state;
            active_sel <= next_active_sel;
            active_rnw_reg <= next_active_rnw_reg;
            active_addr_reg <= next_active_addr_reg;
            word_cnt <= next_word_cnt;
            halt_error <= next_halt_error;
            uncached_rnw_reg <= next_uncached_rnw_reg;
            uncached_wdata_reg <= next_uncached_wdata_reg;
            uncached_rdata_reg <= next_uncached_rdata_reg;
            uncached_wstrb_reg <= next_uncached_wstrb_reg;
            uncached_size_reg <= next_uncached_size_reg;
            uncached_done_reg <= next_uncached_done_reg;
        end
    end

    always_comb begin
        icache_if.gnt = 1'b0; icache_if.valid = 1'b0; icache_if.last = 1'b0; icache_if.rdata = ahbm_if.rdata; icache_if.error = halt_error;
        dcache_if.gnt = 1'b0; dcache_if.valid = 1'b0; dcache_if.last = 1'b0; dcache_if.rdata = ahbm_if.rdata; dcache_if.error = halt_error;
        uncached_if.ready = uncached_done_reg; uncached_if.rdata = uncached_rdata_reg; uncached_if.error = halt_error;
        
        ahbm_if.req = 1'b0; ahbm_if.addr = 32'b0; ahbm_if.rnw = 1'b0; ahbm_if.size = 3'b010; ahbm_if.wdata = 32'b0;

        case (state)
            STATE_IDLE: begin
                // No grants until state changes
                if (!(uncached_if.valid && !uncached_done_reg)) begin
                    if (dcache_if.req) dcache_if.gnt = 1'b1;
                    else if (icache_if.req) icache_if.gnt = 1'b1;
                end
            end
            STATE_XFER: begin
                ahbm_if.req = 1'b1; ahbm_if.rnw = active_rnw_reg; ahbm_if.addr = active_addr_reg + (32'(word_cnt) << 2); ahbm_if.wdata = active_wdata; ahbm_if.size = 3'b010;
                if (ahbm_if.ack) begin
                    if (active_sel) begin dcache_if.valid = 1'b1; dcache_if.last = (word_cnt == 4'(BLOCK_SIZE - 1)); end
                    else begin icache_if.valid = 1'b1; icache_if.last = (word_cnt == 4'(BLOCK_SIZE - 1)); end
                end
            end
            STATE_UNCACHED: begin
                ahbm_if.req = 1'b1; 
                ahbm_if.rnw = uncached_rnw_reg; 
                ahbm_if.addr = active_addr_reg; 
                ahbm_if.wdata = uncached_wdata_reg; 
                ahbm_if.size = uncached_size_reg;
                // We don't assert uncached_if.ready here. We wait for ahbm_if.ack to be registered into uncached_done_reg.
            end
        endcase
    end
endmodule
