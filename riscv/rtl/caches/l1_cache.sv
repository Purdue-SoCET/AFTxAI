`timescale 1ns/1ps
module l1_cache #(parameter int CACHE_SIZE = 1024, parameter int BLOCK_SIZE = 4, parameter int ASSOCIATIVITY = 1, parameter bit CACHE_TYPE = 1) (
    input logic HCLK, input logic nRST,
    cpu_cache_if.cache cpu_if,
    cache_bus_if.cache bus_if,
    l1_cache_if.mp port_unused
);
    localparam int NUM_SETS = CACHE_SIZE / (BLOCK_SIZE * 4 * ASSOCIATIVITY);
    localparam int OFFSET_BITS = (BLOCK_SIZE == 1) ? 2 : $clog2(BLOCK_SIZE * 4);
    localparam int ACTUAL_INDEX_BITS = (NUM_SETS == 1) ? 1 : $clog2(NUM_SETS);
    localparam int TAG_BITS = 32 - OFFSET_BITS - ((NUM_SETS == 1) ? 0 : $clog2(NUM_SETS));

    typedef enum logic [2:0] { STATE_IDLE, STATE_EVICT_REQ, STATE_EVICT_DATA, STATE_FILL_REQ, STATE_FILL_DATA } cache_state_e;
    cache_state_e state, next_state;

    logic [TAG_BITS-1:0] tag_array   [NUM_SETS-1:0][ASSOCIATIVITY-1:0]; logic [TAG_BITS-1:0] next_tag_array   [NUM_SETS-1:0][ASSOCIATIVITY-1:0];
    logic                valid_array [NUM_SETS-1:0][ASSOCIATIVITY-1:0]; logic                next_valid_array [NUM_SETS-1:0][ASSOCIATIVITY-1:0];
    logic                dirty_array [NUM_SETS-1:0][ASSOCIATIVITY-1:0]; logic                next_dirty_array [NUM_SETS-1:0][ASSOCIATIVITY-1:0];
    logic                lru_array   [NUM_SETS-1:0]; logic                next_lru_array   [NUM_SETS-1:0];
    logic [31:0]         data_array  [NUM_SETS-1:0][ASSOCIATIVITY-1:0][BLOCK_SIZE-1:0]; logic [31:0]         next_data_array  [NUM_SETS-1:0][ASSOCIATIVITY-1:0][BLOCK_SIZE-1:0];

    logic [ACTUAL_INDEX_BITS-1:0] cpu_idx; logic [TAG_BITS-1:0] cpu_tag; logic [3:0] cpu_blk_offset;
    logic hit, hit_way, victim_way, next_victim_way; logic [3:0] word_cnt, next_word_cnt;

    always_comb begin
        if (NUM_SETS == 1) cpu_idx = '0; else cpu_idx = cpu_if.addr[OFFSET_BITS +: $clog2(NUM_SETS)];
        if (BLOCK_SIZE == 1) cpu_blk_offset = 4'b0; else cpu_blk_offset = cpu_if.addr[2 +: $clog2(BLOCK_SIZE)];
        cpu_tag = cpu_if.addr[31 : 32-TAG_BITS];
        
        hit = 1'b0; hit_way = 1'b0;
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            if (valid_array[cpu_idx][i] && (tag_array[cpu_idx][i] == cpu_tag)) begin hit = 1'b1; hit_way = i[0]; end
        end
        
        next_state = state; next_word_cnt = word_cnt; next_victim_way = victim_way;
        next_tag_array = tag_array; next_valid_array = valid_array; next_dirty_array = dirty_array;
        next_lru_array = lru_array; next_data_array = data_array;
        
        case (state)
            STATE_IDLE: begin
                if (cpu_if.valid) begin
                    if (hit) begin
                        if (ASSOCIATIVITY == 2) next_lru_array[cpu_idx] = ~hit_way;
                        if (CACHE_TYPE == 1 && cpu_if.wstrb != 4'b0) begin
                            next_dirty_array[cpu_idx][hit_way] = 1'b1;
                            if (cpu_if.wstrb[0]) next_data_array[cpu_idx][hit_way][cpu_blk_offset][7:0]   = cpu_if.wdata[7:0];
                            if (cpu_if.wstrb[1]) next_data_array[cpu_idx][hit_way][cpu_blk_offset][15:8]  = cpu_if.wdata[15:8];
                            if (cpu_if.wstrb[2]) next_data_array[cpu_idx][hit_way][cpu_blk_offset][23:16] = cpu_if.wdata[23:16];
                            if (cpu_if.wstrb[3]) next_data_array[cpu_idx][hit_way][cpu_blk_offset][31:24] = cpu_if.wdata[31:24];
                        end
                    end else begin
                        next_victim_way = (ASSOCIATIVITY == 1) ? 1'b0 : lru_array[cpu_idx];
                        next_word_cnt = '0;
                        if (CACHE_TYPE == 1 && valid_array[cpu_idx][next_victim_way] && dirty_array[cpu_idx][next_victim_way]) next_state = STATE_EVICT_REQ;
                        else next_state = STATE_FILL_REQ;
                    end
                end
            end
            STATE_EVICT_REQ: if (bus_if.gnt) next_state = STATE_EVICT_DATA;
            STATE_EVICT_DATA: if (bus_if.valid) begin if (bus_if.last) next_state = STATE_FILL_REQ; else next_word_cnt = word_cnt + 1; end
            STATE_FILL_REQ: if (bus_if.gnt) next_state = STATE_FILL_DATA;
            STATE_FILL_DATA: if (bus_if.valid) begin
                next_data_array[cpu_idx][victim_way][word_cnt] = bus_if.rdata;
                if (bus_if.last) begin
                    next_valid_array[cpu_idx][victim_way] = 1'b1; next_dirty_array[cpu_idx][victim_way] = 1'b0;
                    next_tag_array[cpu_idx][victim_way] = cpu_tag; next_state = STATE_IDLE;
                end else next_word_cnt = word_cnt + 1;
            end
        endcase
    end

    always_ff @(posedge HCLK or negedge nRST) begin
        if (!nRST) begin
            state <= STATE_IDLE; word_cnt <= '0; victim_way <= 1'b0;
            for (int s = 0; s < NUM_SETS; s++) begin
                lru_array[s] <= 1'b0;
                for (int w = 0; w < ASSOCIATIVITY; w++) begin valid_array[s][w] <= 1'b0; dirty_array[s][w] <= 1'b0; tag_array[s][w] <= '0; end
            end
        end else begin
            state <= next_state; word_cnt <= next_word_cnt; victim_way <= next_victim_way;
            tag_array <= next_tag_array; valid_array <= next_valid_array; dirty_array <= next_dirty_array;
            lru_array <= next_lru_array; data_array <= next_data_array;
        end
    end

    logic [31:0] evict_addr, fill_addr;
    always_comb begin
        if (NUM_SETS == 1) begin evict_addr = {tag_array[cpu_idx][victim_way], {OFFSET_BITS{1'b0}}}; fill_addr  = {cpu_tag, {OFFSET_BITS{1'b0}}}; end
        else begin evict_addr = {tag_array[cpu_idx][victim_way], cpu_idx[$clog2(NUM_SETS)-1:0], {OFFSET_BITS{1'b0}}}; fill_addr  = {cpu_tag, cpu_idx[$clog2(NUM_SETS)-1:0], {OFFSET_BITS{1'b0}}}; end
        bus_if.req = 1'b0; bus_if.addr = 32'b0; bus_if.rnw = 1'b0; bus_if.wdata = 32'b0;
        case (state)
            STATE_EVICT_REQ: begin bus_if.req = 1'b1; bus_if.rnw = 1'b0; bus_if.addr = evict_addr; end
            STATE_EVICT_DATA: bus_if.wdata = data_array[cpu_idx][victim_way][word_cnt];
            STATE_FILL_REQ: begin bus_if.req = 1'b1; bus_if.rnw = 1'b1; bus_if.addr = fill_addr; end
            default: ;
        endcase
    end
    assign cpu_if.ready = (state == STATE_IDLE && hit);
    assign cpu_if.rdata = (state == STATE_IDLE && hit) ? data_array[cpu_idx][hit_way][cpu_blk_offset] : 32'b0;
    assign cpu_if.error = bus_if.error;
endmodule
