`timescale 1ns/1ps

module l1_cache #(
    parameter int CACHE_SIZE = 1024,
    parameter int BLOCK_SIZE = 4,
    parameter int ASSOCIATIVITY = 1,
    parameter bit CACHE_TYPE = 1 // 0 for iCache (Read-Only), 1 for dCache (Write-Back/Write-Allocate)
) (
    input  logic HCLK,
    input  logic nRST,

    // CPU to Cache Interface
    cpu_cache_if.cache cpu_if,

    // Cache to Bus Controller Interface
    cache_bus_if.cache bus_if
);

    // --- Parameter Derived Constants ---
    localparam int NUM_SETS = CACHE_SIZE / (BLOCK_SIZE * 4 * ASSOCIATIVITY);
    localparam int OFFSET_BITS = (BLOCK_SIZE == 1) ? 2 : $clog2(BLOCK_SIZE * 4);
    localparam int ACTUAL_INDEX_BITS = (NUM_SETS == 1) ? 1 : $clog2(NUM_SETS);
    localparam int TAG_BITS = 32 - OFFSET_BITS - ((NUM_SETS == 1) ? 0 : $clog2(NUM_SETS));

    // --- State Machine ---
    typedef enum logic [2:0] {
        STATE_IDLE,
        STATE_EVICT_REQ,
        STATE_EVICT_DATA,
        STATE_FILL_REQ,
        STATE_FILL_DATA
    } cache_state_e;

    cache_state_e state_q;

    // --- Cache SRAM Arrays ---
    logic [TAG_BITS-1:0] tag_array   [NUM_SETS-1:0][ASSOCIATIVITY-1:0];
    logic                valid_array [NUM_SETS-1:0][ASSOCIATIVITY-1:0];
    logic                dirty_array [NUM_SETS-1:0][ASSOCIATIVITY-1:0];
    logic                lru_array   [NUM_SETS-1:0]; // 0: way 0 is LRU, 1: way 1 is LRU
    logic [31:0]         data_array  [NUM_SETS-1:0][ASSOCIATIVITY-1:0][BLOCK_SIZE-1:0];

    // --- Address Decoding ---
    logic [ACTUAL_INDEX_BITS-1:0] cpu_idx;
    logic [TAG_BITS-1:0]          cpu_tag;
    logic [3:0]                   cpu_blk_offset;

    always_comb begin
        if (NUM_SETS == 1) cpu_idx = '0;
        else cpu_idx = cpu_if.addr[OFFSET_BITS +: $clog2(NUM_SETS)];
        
        if (BLOCK_SIZE == 1) cpu_blk_offset = 4'b0;
        else cpu_blk_offset = cpu_if.addr[2 +: $clog2(BLOCK_SIZE)];
    end

    assign cpu_tag = cpu_if.addr[31 : 32-TAG_BITS];

    // --- Hit Detection (Combinational) ---
    logic hit, hit_way;
    always_comb begin
        hit = 1'b0;
        hit_way = 1'b0;
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            if (valid_array[cpu_idx][i] && (tag_array[cpu_idx][i] == cpu_tag)) begin
                hit = 1'b1;
                hit_way = i[0];
            end
        end
    end

    // --- FSM Registers ---
    logic victim_way_q;
    logic [3:0] word_cnt_q;

    always_ff @(posedge HCLK or negedge nRST) begin
        if (!nRST) begin
            state_q <= STATE_IDLE;
            word_cnt_q <= '0;
            victim_way_q <= 1'b0;
            for (int s = 0; s < NUM_SETS; s++) begin
                lru_array[s] <= 1'b0;
                for (int w = 0; w < ASSOCIATIVITY; w++) begin
                    valid_array[s][w] <= 1'b0;
                    dirty_array[s][w] <= 1'b0;
                    tag_array[s][w] <= '0;
                end
            end
        end else begin
            case (state_q)
                STATE_IDLE: begin
                    if (cpu_if.valid) begin
                        if (hit) begin
                            // Update LRU on hit
                            if (ASSOCIATIVITY == 2) lru_array[cpu_idx] <= ~hit_way;
                            
                            // Handle Write
                            if (CACHE_TYPE == 1 && cpu_if.wstrb != 4'b0) begin
                                dirty_array[cpu_idx][hit_way] <= 1'b1;
                                if (cpu_if.wstrb[0]) data_array[cpu_idx][hit_way][cpu_blk_offset][7:0]   <= cpu_if.wdata[7:0];
                                if (cpu_if.wstrb[1]) data_array[cpu_idx][hit_way][cpu_blk_offset][15:8]  <= cpu_if.wdata[15:8];
                                if (cpu_if.wstrb[2]) data_array[cpu_idx][hit_way][cpu_blk_offset][23:16] <= cpu_if.wdata[23:16];
                                if (cpu_if.wstrb[3]) data_array[cpu_idx][hit_way][cpu_blk_offset][31:24] <= cpu_if.wdata[31:24];
                            end
                        end else begin
                            // Miss Handling
                            victim_way_q <= (ASSOCIATIVITY == 1) ? 1'b0 : lru_array[cpu_idx];
                            word_cnt_q <= '0;
                            
                            // Write-back dirty line or jump straight to fill
                            if (CACHE_TYPE == 1 && 
                                valid_array[cpu_idx][(ASSOCIATIVITY == 1) ? 1'b0 : lru_array[cpu_idx]] &&
                                dirty_array[cpu_idx][(ASSOCIATIVITY == 1) ? 1'b0 : lru_array[cpu_idx]]) begin
                                state_q <= STATE_EVICT_REQ;
                            end else begin
                                state_q <= STATE_FILL_REQ;
                            end
                        end
                    end
                end

                STATE_EVICT_REQ: begin
                    if (bus_if.gnt) state_q <= STATE_EVICT_DATA;
                end

                STATE_EVICT_DATA: begin
                    if (bus_if.valid) begin
                        if (bus_if.last) state_q <= STATE_FILL_REQ;
                        else word_cnt_q <= word_cnt_q + 1;
                    end
                end

                STATE_FILL_REQ: begin
                    if (bus_if.gnt) state_q <= STATE_FILL_DATA;
                end

                STATE_FILL_DATA: begin
                    if (bus_if.valid) begin
                        data_array[cpu_idx][victim_way_q][word_cnt_q] <= bus_if.rdata;
                        if (bus_if.last) begin
                            valid_array[cpu_idx][victim_way_q] <= 1'b1;
                            dirty_array[cpu_idx][victim_way_q] <= 1'b0;
                            tag_array[cpu_idx][victim_way_q] <= cpu_tag;
                            state_q <= STATE_IDLE;
                        end else begin
                            word_cnt_q <= word_cnt_q + 1;
                        end
                    end
                end
            endcase
        end
    end

    // --- Bus Controller Interface (Combinational) ---
    logic [31:0] evict_addr;
    logic [31:0] fill_addr;

    always_comb begin
        if (NUM_SETS == 1) begin
            evict_addr = {tag_array[cpu_idx][victim_way_q], {OFFSET_BITS{1'b0}}};
            fill_addr  = {cpu_tag, {OFFSET_BITS{1'b0}}};
        end else begin
            evict_addr = {tag_array[cpu_idx][victim_way_q], cpu_idx[$clog2(NUM_SETS)-1:0], {OFFSET_BITS{1'b0}}};
            fill_addr  = {cpu_tag, cpu_idx[$clog2(NUM_SETS)-1:0], {OFFSET_BITS{1'b0}}};
        end
    end

    always_comb begin
        bus_if.req = 1'b0;
        bus_if.addr = 32'b0;
        bus_if.rnw = 1'b0;
        bus_if.wdata = 32'b0;

        case (state_q)
            STATE_EVICT_REQ: begin
                bus_if.req = 1'b1;
                bus_if.rnw = 1'b0; // Write (Evict)
                bus_if.addr = evict_addr;
            end
            STATE_EVICT_DATA: begin
                bus_if.wdata = data_array[cpu_idx][victim_way_q][word_cnt_q];
            end
            STATE_FILL_REQ: begin
                bus_if.req = 1'b1;
                bus_if.rnw = 1'b1; // Read (Fill)
                bus_if.addr = fill_addr;
            end
            default: ;
        endcase
    end

    // --- CPU Interface ---
    assign cpu_if.ready = (state_q == STATE_IDLE && hit);
    assign cpu_if.rdata = (state_q == STATE_IDLE && hit) ? data_array[cpu_idx][hit_way][cpu_blk_offset] : 32'b0;
    assign cpu_if.error = bus_if.error;

endmodule
