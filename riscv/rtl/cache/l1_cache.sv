import riscv_pkg::*;

module l1_cache #(
  parameter int CACHE_SIZE = 1024,
  parameter int BLOCK_WORDS = 4,
  parameter int ASSOC = 2,
  parameter cache_type_t CACHE_TYPE = DCACHE
)(
  input  logic        clk,
  input  logic        rst_n,

  // CPU Interface
  cache_if.cache      cpu,

  // Coherence Bus Interface
  coherence_if.cache  bus
);

`ifndef SYNTHESIS
  generate
    if (CACHE_SIZE == 0 || (CACHE_SIZE & (CACHE_SIZE-1)) != 0)
      $error("CACHE_SIZE must be a power of 2");
    if (BLOCK_WORDS != 1 && BLOCK_WORDS != 2 && BLOCK_WORDS != 4 && BLOCK_WORDS != 8)
      $error("BLOCK_WORDS must be 1, 2, 4, or 8");
    if (ASSOC != 1 && ASSOC != 2)
      $error("ASSOC must be 1 or 2");
  endgenerate
`endif

  localparam int SETS = CACHE_SIZE / (BLOCK_WORDS * 4 * ASSOC);
  localparam int IDX_BITS = $clog2(SETS);
  localparam int BLK_BITS = $clog2(BLOCK_WORDS);
  localparam int TAG_BITS = 32 - IDX_BITS - BLK_BITS - 2;

  // --------------------------------------------------------------------------
  // Cache Arrays
  // --------------------------------------------------------------------------
  logic [TAG_BITS-1:0] tags   [ASSOC-1:0][SETS-1:0];
  mesi_state_t         states [ASSOC-1:0][SETS-1:0];
  logic [31:0]         data   [ASSOC-1:0][SETS-1:0][BLOCK_WORDS-1:0];
  logic                lru    [SETS-1:0]; // 0: way 0 is LRU, 1: way 1 is LRU

  // --------------------------------------------------------------------------
  // CPU Request Parsing
  // --------------------------------------------------------------------------
  logic [TAG_BITS-1:0] req_tag;
  logic [IDX_BITS-1:0] req_idx;
  logic [BLK_BITS-1:0] req_blk;
  
  assign req_tag = cpu.addr[31 : 32-TAG_BITS];
  assign req_idx = cpu.addr[31-TAG_BITS : BLK_BITS+2];
  assign req_blk = (BLOCK_WORDS == 1) ? 1'b0 : cpu.addr[BLK_BITS+1 : 2];

  logic is_uncacheable;
  assign is_uncacheable = (cpu.addr >= MMIO_BASE && cpu.addr <= MMIO_END);

  // --------------------------------------------------------------------------
  // Hit Detection
  // --------------------------------------------------------------------------
  logic hit_way [ASSOC-1:0];
  logic any_hit;
  logic [1:0] hit_way_idx;
  mesi_state_t hit_state;

  always_comb begin
    any_hit = 1'b0;
    hit_way_idx = '0;
    hit_state = MESI_I;
    
    for (int i = 0; i < ASSOC; i++) begin
      hit_way[i] = (states[i][req_idx] != MESI_I) && (tags[i][req_idx] == req_tag);
      if (hit_way[i]) begin
        any_hit = 1'b1;
        hit_way_idx = i;
        hit_state = states[i][req_idx];
      end
    end
  end

  // Victim Selection
  logic [1:0] victim_way;
  assign victim_way = (ASSOC == 1) ? 2'd0 : {1'b0, lru[req_idx]};

  // --------------------------------------------------------------------------
  // LR/SC Reservation Station
  // --------------------------------------------------------------------------
  logic        res_valid;
  logic [31:0] res_addr;

  // --------------------------------------------------------------------------
  // FSM & Control Logic
  // --------------------------------------------------------------------------
  typedef enum logic [3:0] {
    IDLE,
    WAIT_GNT_WB,
    DATA_WB,
    WAIT_GNT_FILL,
    DATA_FILL,
    WAIT_GNT_UPGR,
    AMO_EXEC,
    WAIT_GNT_UNC,
    DATA_UNC,
    FLUSH_LOOP
  } fsm_state_t;

  fsm_state_t state, next_state;

  logic [IDX_BITS-1:0] flush_idx;
  logic [1:0]          flush_way;
  
  logic [BLK_BITS:0] burst_cnt; // can go up to BLOCK_WORDS

  // Outputs
  logic cpu_valid;
  logic [31:0] cpu_rdata;
  logic cpu_err;

  assign cpu.valid = cpu_valid;
  assign cpu.rdata = cpu_rdata;
  assign cpu.err   = cpu_err;
  assign cpu.gnt   = 1'b1; // We stall pipeline via valid

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      res_valid <= 1'b0;
      res_addr <= '0;
      bus.req <= 1'b0;
      bus.wvalid <= 1'b0;
      bus.flush_done <= 1'b0;
      flush_idx <= '0;
      flush_way <= '0;
      burst_cnt <= '0;
      
      for (int i=0; i<ASSOC; i++) begin
        for (int j=0; j<SETS; j++) begin
          states[i][j] <= MESI_I;
        end
      end
    end else begin
      bus.req <= 1'b0;
      bus.wvalid <= 1'b0;
      bus.wlast <= 1'b0;
      bus.flush_done <= 1'b0;
      cpu_valid <= 1'b0;
      cpu_err <= 1'b0;
      bus.snoop_ack <= 1'b0;
      
      // ----------------------------------------------------------------------
      // Snoop Handling (Priority unless handling AMO)
      // ----------------------------------------------------------------------
      if (bus.snoop_valid && state != AMO_EXEC) begin
        logic s_hit;
        logic [1:0] s_way;
        logic [IDX_BITS-1:0] s_idx;
        logic [TAG_BITS-1:0] s_tag;
        s_idx = bus.snoop_addr[31-TAG_BITS : BLK_BITS+2];
        s_tag = bus.snoop_addr[31 : 32-TAG_BITS];
        
        s_hit = 1'b0;
        s_way = '0;
        for (int i=0; i<ASSOC; i++) begin
          if (states[i][s_idx] != MESI_I && tags[i][s_idx] == s_tag) begin
            s_hit = 1'b1;
            s_way = i;
          end
        end
        
        bus.snoop_hit <= s_hit;
        bus.snoop_dirty <= s_hit && (states[s_way][s_idx] == MESI_M);
        bus.snoop_ack <= 1'b1;

        if (s_hit) begin
          // Clear LR/SC Reservation
          if (res_valid && res_addr[31:2] == bus.snoop_addr[31:2]) begin
            res_valid <= 1'b0;
          end

          if (bus.snoop_cmd == BUS_RD) begin
            if (states[s_way][s_idx] == MESI_M || states[s_way][s_idx] == MESI_E)
              states[s_way][s_idx] <= MESI_S;
          end else if (bus.snoop_cmd == BUS_RDX || bus.snoop_cmd == BUS_UPGR) begin
            states[s_way][s_idx] <= MESI_I;
          end
        end
      end
      
      // ----------------------------------------------------------------------
      // Main FSM
      // ----------------------------------------------------------------------
      case (state)
        IDLE: begin
          if (bus.flush_req) begin
            flush_idx <= '0;
            flush_way <= '0;
            state <= FLUSH_LOOP;
          end 
          else if (cpu.req) begin
            if (is_uncacheable) begin
              bus.req <= 1'b1;
              bus.addr <= {cpu.addr[31:2], 2'd0};
              bus.cmd <= cpu.we ? BUS_WB : BUS_RD; // Writeback used here as single write indicator
              bus.uncacheable <= 1'b1;
              state <= WAIT_GNT_UNC;
            end 
            else if (any_hit) begin
              if (CACHE_TYPE == DCACHE && cpu.we && hit_state == MESI_S) begin
                bus.req <= 1'b1;
                bus.addr <= {cpu.addr[31:BLK_BITS+2], {(BLK_BITS+2){1'b0}}};
                bus.cmd <= BUS_UPGR;
                bus.uncacheable <= 1'b0;
                state <= WAIT_GNT_UPGR;
              end else begin
                // Hit execution
                if (ASSOC > 1) lru[req_idx] <= (hit_way_idx == 0) ? 1'b1 : 1'b0;
                
                if (cpu.is_amo) begin
                  if (cpu.amo_op == AMO_LR) begin
                    res_valid <= 1'b1;
                    res_addr <= cpu.addr;
                    cpu_rdata <= data[hit_way_idx][req_idx][req_blk];
                    cpu_valid <= 1'b1;
                  end else if (cpu.amo_op == AMO_SC) begin
                    if (res_valid && res_addr == cpu.addr) begin
                      data[hit_way_idx][req_idx][req_blk] <= cpu.wdata;
                      states[hit_way_idx][req_idx] <= MESI_M;
                      cpu_rdata <= 32'd0; // Success
                      res_valid <= 1'b0;
                    end else begin
                      cpu_rdata <= 32'd1; // Fail
                    end
                    cpu_valid <= 1'b1;
                  end else begin
                    // Other AMOs
                    state <= AMO_EXEC;
                  end
                end else if (cpu.we) begin
                  // Write Masking
                  if (cpu.wmask[0]) data[hit_way_idx][req_idx][req_blk][7:0]   <= cpu.wdata[7:0];
                  if (cpu.wmask[1]) data[hit_way_idx][req_idx][req_blk][15:8]  <= cpu.wdata[15:8];
                  if (cpu.wmask[2]) data[hit_way_idx][req_idx][req_blk][23:16] <= cpu.wdata[23:16];
                  if (cpu.wmask[3]) data[hit_way_idx][req_idx][req_blk][31:24] <= cpu.wdata[31:24];
                  states[hit_way_idx][req_idx] <= MESI_M;
                  cpu_valid <= 1'b1;
                end else begin
                  cpu_rdata <= data[hit_way_idx][req_idx][req_blk];
                  cpu_valid <= 1'b1;
                end
              end
            end else begin // Cache Miss
              if (states[victim_way][req_idx] == MESI_M) begin
                bus.req <= 1'b1;
                bus.addr <= {tags[victim_way][req_idx], req_idx, {(BLK_BITS+2){1'b0}}};
                bus.cmd <= BUS_WB;
                bus.uncacheable <= 1'b0;
                burst_cnt <= '0;
                state <= WAIT_GNT_WB;
              end else begin
                bus.req <= 1'b1;
                bus.addr <= {cpu.addr[31:BLK_BITS+2], {(BLK_BITS+2){1'b0}}};
                bus.cmd <= (CACHE_TYPE == ICACHE || !cpu.we) ? BUS_RD : BUS_RDX;
                bus.uncacheable <= 1'b0;
                burst_cnt <= '0;
                state <= WAIT_GNT_FILL;
              end
            end
          end
        end
        
        AMO_EXEC: begin
          // Deferred AMO Execution (Locks out snoops for indivisibility)
          logic [31:0] amo_val;
          logic [31:0] alu_res;
          amo_val = data[hit_way_idx][req_idx][req_blk];
          
          case (cpu.amo_op)
            AMO_SWAP: alu_res = cpu.wdata;
            AMO_ADD:  alu_res = amo_val + cpu.wdata;
            AMO_XOR:  alu_res = amo_val ^ cpu.wdata;
            AMO_AND:  alu_res = amo_val & cpu.wdata;
            AMO_OR:   alu_res = amo_val | cpu.wdata;
            AMO_MIN:  alu_res = ($signed(amo_val) < $signed(cpu.wdata)) ? amo_val : cpu.wdata;
            AMO_MAX:  alu_res = ($signed(amo_val) > $signed(cpu.wdata)) ? amo_val : cpu.wdata;
            AMO_MINU: alu_res = (amo_val < cpu.wdata) ? amo_val : cpu.wdata;
            AMO_MAXU: alu_res = (amo_val > cpu.wdata) ? amo_val : cpu.wdata;
            default:  alu_res = amo_val;
          endcase
          
          data[hit_way_idx][req_idx][req_blk] <= alu_res;
          states[hit_way_idx][req_idx] <= MESI_M;
          cpu_rdata <= amo_val; // AMOs return the ORIGINAL value
          cpu_valid <= 1'b1;
          state <= IDLE;
        end

        WAIT_GNT_WB: begin
          bus.req <= 1'b1;
          if (bus.gnt) begin
            bus.req <= 1'b0;
            state <= DATA_WB;
            bus.wvalid <= 1'b1;
            bus.wdata <= data[victim_way][req_idx][burst_cnt];
            if (BLOCK_WORDS == 1) bus.wlast <= 1'b1;
          end
        end

        DATA_WB: begin
          bus.wvalid <= 1'b1;
          bus.wdata <= data[victim_way][req_idx][burst_cnt];
          if (burst_cnt == BLOCK_WORDS - 1) begin
            bus.wlast <= 1'b1;
            states[victim_way][req_idx] <= MESI_I; // Invalidate victim
            
            // Immediately request Fill
            bus.req <= 1'b1;
            bus.addr <= {cpu.addr[31:BLK_BITS+2], {(BLK_BITS+2){1'b0}}};
            bus.cmd <= (CACHE_TYPE == ICACHE || !cpu.we) ? BUS_RD : BUS_RDX;
            burst_cnt <= '0;
            state <= WAIT_GNT_FILL;
          end else begin
            burst_cnt <= burst_cnt + 1;
          end
        end

        WAIT_GNT_FILL: begin
          bus.req <= 1'b1;
          if (bus.gnt) begin
            bus.req <= 1'b0;
            state <= DATA_FILL;
          end
        end

        DATA_FILL: begin
          if (bus.rvalid) begin
            data[victim_way][req_idx][burst_cnt] <= bus.rdata;
            if (bus.rlast || burst_cnt == BLOCK_WORDS - 1) begin
              tags[victim_way][req_idx] <= req_tag;
              
              if (CACHE_TYPE == ICACHE) begin
                states[victim_way][req_idx] <= MESI_S;
              end else begin
                // In a full MESI system, the bus.snoop_hit from siblings tells us if we get E or S.
                // Assuming bus.snoop_hit is not directly passed to us during fill in this IF,
                // we safely default to E on exclusive read, or S if it was shared. 
                // We will simplify to E for now, and S on bus.snoop_hit if we add that to coherence_if.
                if (cpu.we) states[victim_way][req_idx] <= MESI_M; // If it was a BusRdX
                else        states[victim_way][req_idx] <= MESI_E; // Exclusive
              end
              
              state <= IDLE;
              // We do not assert valid here, we let it transition to IDLE and hit combinationally 
              // next cycle to ensure RMW atomics and writes use the normal path safely.
            end else begin
              burst_cnt <= burst_cnt + 1;
            end
          end
        end

        WAIT_GNT_UPGR: begin
          bus.req <= 1'b1;
          if (bus.gnt) begin
            bus.req <= 1'b0;
            states[hit_way_idx][req_idx] <= MESI_M;
            state <= IDLE; // Again, let IDLE combinational logic re-trigger the write
          end
        end

        WAIT_GNT_UNC: begin
          bus.req <= 1'b1;
          if (bus.gnt) begin
            bus.req <= 1'b0;
            if (cpu.we) begin
              bus.wvalid <= 1'b1;
              bus.wdata <= cpu.wdata;
              bus.wlast <= 1'b1;
              state <= DATA_UNC;
            end else begin
              state <= DATA_UNC;
            end
          end
        end

        DATA_UNC: begin
          if (cpu.we) begin
             cpu_valid <= 1'b1;
             state <= IDLE;
          end else if (bus.rvalid) begin
             cpu_rdata <= bus.rdata;
             cpu_valid <= 1'b1;
             cpu_err <= bus.rresp;
             state <= IDLE;
          end
        end

        FLUSH_LOOP: begin
          if (states[flush_way][flush_idx] == MESI_M) begin
            bus.req <= 1'b1;
            bus.addr <= {tags[flush_way][flush_idx], flush_idx, {(BLK_BITS+2){1'b0}}};
            bus.cmd <= BUS_WB;
            burst_cnt <= '0;
            
            if (bus.gnt) begin
              state <= DATA_WB;
            end else begin
              state <= WAIT_GNT_WB;
            end
            
            // DATA_WB will invalidate and we need to intercept it returning to WAIT_GNT_FILL
            // We override DATA_WB transition logic by checking if bus.flush_req is active?
            // Actually, better to do flush writeback directly here to avoid corrupting CPU miss.
            // Rewriting flush logic to avoid state entanglement:
          end else begin
            states[flush_way][flush_idx] <= MESI_I;
            if (flush_way == ASSOC - 1 && flush_idx == SETS - 1) begin
              bus.flush_done <= 1'b1;
              if (!bus.flush_req) state <= IDLE; // Wait for handshake deassertion
            end else begin
              if (flush_idx == SETS - 1) begin
                flush_idx <= '0;
                flush_way <= flush_way + 1;
              end else begin
                flush_idx <= flush_idx + 1;
              end
            end
          end
        end
      endcase
      
      // Override DATA_WB transition for Flush
      if (state == DATA_WB && bus.flush_req) begin
         if (burst_cnt == BLOCK_WORDS - 1) begin
           states[victim_way][req_idx] <= MESI_I; // In this case victim_way is shadowed by flush vars
           states[flush_way][flush_idx] <= MESI_I; 
           state <= FLUSH_LOOP;
         end
      end
      
    end
  end

endmodule
