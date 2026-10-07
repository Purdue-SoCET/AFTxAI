import riscv_pkg::*;

module memory_controller (
  input  logic        clk,
  input  logic        rst_n,

  // Cache Interfaces
  coherence_if.mc     icache0,
  coherence_if.mc     dcache0,
  coherence_if.mc     icache1,
  coherence_if.mc     dcache1,

  // AHB-Lite Master Interface
  ahb_if.master       ahb
);

  // --------------------------------------------------------------------------
  // Arbitration (Round Robin)
  // --------------------------------------------------------------------------
  logic [3:0] reqs;
  assign reqs = {dcache1.req, icache1.req, dcache0.req, icache0.req};

  logic [1:0] grant_idx, next_grant_idx;
  logic       any_req;

  always_comb begin
    any_req = |reqs;
    next_grant_idx = grant_idx;
    
    if (any_req) begin
      if      (reqs[(grant_idx + 1) % 4]) next_grant_idx = (grant_idx + 1) % 4;
      else if (reqs[(grant_idx + 2) % 4]) next_grant_idx = (grant_idx + 2) % 4;
      else if (reqs[(grant_idx + 3) % 4]) next_grant_idx = (grant_idx + 3) % 4;
      else                                next_grant_idx = grant_idx;
    end
  end

  // Multiplexed Master Signals
  logic        active_req;
  logic [31:0] active_addr;
  bus_cmd_t    active_cmd;
  logic        active_uncacheable;
  logic        active_wvalid;
  logic [31:0] active_wdata;
  logic        active_wlast;

  always_comb begin
    active_req = 1'b0;
    active_addr = '0;
    active_cmd = BUS_NONE;
    active_uncacheable = 1'b0;
    active_wvalid = 1'b0;
    active_wdata = '0;
    active_wlast = 1'b0;

    case (grant_idx)
      2'd0: begin active_req = icache0.req; active_addr = icache0.addr; active_cmd = icache0.cmd; active_uncacheable = icache0.uncacheable; active_wvalid = icache0.wvalid; active_wdata = icache0.wdata; active_wlast = icache0.wlast; end
      2'd1: begin active_req = dcache0.req; active_addr = dcache0.addr; active_cmd = dcache0.cmd; active_uncacheable = dcache0.uncacheable; active_wvalid = dcache0.wvalid; active_wdata = dcache0.wdata; active_wlast = dcache0.wlast; end
      2'd2: begin active_req = icache1.req; active_addr = icache1.addr; active_cmd = icache1.cmd; active_uncacheable = icache1.uncacheable; active_wvalid = icache1.wvalid; active_wdata = icache1.wdata; active_wlast = icache1.wlast; end
      2'd3: begin active_req = dcache1.req; active_addr = dcache1.addr; active_cmd = dcache1.cmd; active_uncacheable = dcache1.uncacheable; active_wvalid = dcache1.wvalid; active_wdata = dcache1.wdata; active_wlast = dcache1.wlast; end
    endcase
  end

  // --------------------------------------------------------------------------
  // Snoop Broadcasting
  // --------------------------------------------------------------------------
  logic snoop_req;
  
  assign icache0.snoop_valid = snoop_req && (grant_idx != 2'd0);
  assign dcache0.snoop_valid = snoop_req && (grant_idx != 2'd1);
  assign icache1.snoop_valid = snoop_req && (grant_idx != 2'd2);
  assign dcache1.snoop_valid = snoop_req && (grant_idx != 2'd3);

  assign icache0.snoop_cmd = active_cmd;
  assign dcache0.snoop_cmd = active_cmd;
  assign icache1.snoop_cmd = active_cmd;
  assign dcache1.snoop_cmd = active_cmd;

  assign icache0.snoop_addr = active_addr;
  assign dcache0.snoop_addr = active_addr;
  assign icache1.snoop_addr = active_addr;
  assign dcache1.snoop_addr = active_addr;

  logic all_snoops_acked;
  logic any_snoop_dirty;
  logic [1:0] dirty_owner;

  always_comb begin
    all_snoops_acked = 1'b1;
    any_snoop_dirty = 1'b0;
    dirty_owner = 2'd0;

    if (grant_idx != 2'd0) begin all_snoops_acked &= icache0.snoop_ack; if (icache0.snoop_dirty) begin any_snoop_dirty = 1'b1; dirty_owner = 2'd0; end end
    if (grant_idx != 2'd1) begin all_snoops_acked &= dcache0.snoop_ack; if (dcache0.snoop_dirty) begin any_snoop_dirty = 1'b1; dirty_owner = 2'd1; end end
    if (grant_idx != 2'd2) begin all_snoops_acked &= icache1.snoop_ack; if (icache1.snoop_dirty) begin any_snoop_dirty = 1'b1; dirty_owner = 2'd2; end end
    if (grant_idx != 2'd3) begin all_snoops_acked &= dcache1.snoop_ack; if (dcache1.snoop_dirty) begin any_snoop_dirty = 1'b1; dirty_owner = 2'd3; end end
  end

  // --------------------------------------------------------------------------
  // AHB Controller FSM
  // --------------------------------------------------------------------------
  typedef enum logic [3:0] {
    IDLE,
    SNOOP_WAIT,
    OWNER_WB_FLUSH,
    AHB_ADDR_PHASE,
    AHB_DATA_PHASE,
    AHB_BURST_DATA
  } mc_state_t;

  mc_state_t state;
  logic [2:0] burst_count; // Tracks words transferred

  // Demux Read Data
  always_comb begin
    icache0.rvalid = 1'b0; icache0.rdata = ahb.hrdata; icache0.rlast = 1'b0; icache0.rresp = ahb.hresp;
    dcache0.rvalid = 1'b0; dcache0.rdata = ahb.hrdata; dcache0.rlast = 1'b0; dcache0.rresp = ahb.hresp;
    icache1.rvalid = 1'b0; icache1.rdata = ahb.hrdata; icache1.rlast = 1'b0; icache1.rresp = ahb.hresp;
    dcache1.rvalid = 1'b0; dcache1.rdata = ahb.hrdata; dcache1.rlast = 1'b0; dcache1.rresp = ahb.hresp;

    if (state == AHB_DATA_PHASE || state == AHB_BURST_DATA) begin
      if (ahb.hready) begin
        case (grant_idx)
          2'd0: begin icache0.rvalid = 1'b1; icache0.rlast = (burst_count == 3); end
          2'd1: begin dcache0.rvalid = 1'b1; dcache0.rlast = (burst_count == 3); end
          2'd2: begin icache1.rvalid = 1'b1; icache1.rlast = (burst_count == 3); end
          2'd3: begin dcache1.rvalid = 1'b1; dcache1.rlast = (burst_count == 3); end
        endcase
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      grant_idx <= 2'd0;
      snoop_req <= 1'b0;
      burst_count <= '0;
      ahb.htrans <= 2'b00; // IDLE
      ahb.hwrite <= 1'b0;
      
      icache0.gnt <= 1'b0;
      dcache0.gnt <= 1'b0;
      icache1.gnt <= 1'b0;
      dcache1.gnt <= 1'b0;
    end else begin
      icache0.gnt <= 1'b0;
      dcache0.gnt <= 1'b0;
      icache1.gnt <= 1'b0;
      dcache1.gnt <= 1'b0;
      
      case (state)
        IDLE: begin
          if (any_req) begin
            grant_idx <= next_grant_idx;
            // Uncacheable / Writebacks skip snoop
            if (active_uncacheable || active_cmd == BUS_WB) begin
              state <= AHB_ADDR_PHASE;
              
              case (next_grant_idx)
                2'd0: icache0.gnt <= 1'b1;
                2'd1: dcache0.gnt <= 1'b1;
                2'd2: icache1.gnt <= 1'b1;
                2'd3: dcache1.gnt <= 1'b1;
              endcase
            end else if (active_cmd == BUS_UPGR) begin
              snoop_req <= 1'b1;
              state <= SNOOP_WAIT;
            end else begin
              snoop_req <= 1'b1;
              state <= SNOOP_WAIT;
            end
          end
        end

        SNOOP_WAIT: begin
          if (all_snoops_acked) begin
            snoop_req <= 1'b0;
            if (active_cmd == BUS_UPGR) begin
              // Upgrade requires no memory access, just invalidate others
              case (grant_idx)
                2'd0: icache0.gnt <= 1'b1;
                2'd1: dcache0.gnt <= 1'b1;
                2'd2: icache1.gnt <= 1'b1;
                2'd3: dcache1.gnt <= 1'b1;
              endcase
              state <= IDLE;
            end else if (any_snoop_dirty) begin
              // Architectural decision: owner writes back to memory, then we read it.
              // In this simplified FSM, we jump to a state where the dirty owner flushes.
              // We'll instruct the dirty owner cache to perform a WB implicitly since it transitioned to I/S.
              // Actually, the dirty cache transitions automatically to I/S and will assert bus.req for WB if needed.
              // We'll abort current request, let it retry, and arbitrate the WB first.
              state <= IDLE; 
            end else begin
              state <= AHB_ADDR_PHASE;
              case (grant_idx)
                2'd0: icache0.gnt <= 1'b1;
                2'd1: dcache0.gnt <= 1'b1;
                2'd2: icache1.gnt <= 1'b1;
                2'd3: dcache1.gnt <= 1'b1;
              endcase
            end
          end
        end

        AHB_ADDR_PHASE: begin
          ahb.haddr <= active_addr;
          ahb.hwrite <= (active_cmd == BUS_WB || (active_uncacheable && active_wvalid));
          ahb.hsize <= 3'b010; // 32-bit Word
          ahb.hburst <= (active_uncacheable) ? 3'b000 : 3'b011; // SINGLE or INCR4
          ahb.htrans <= 2'b10; // NONSEQ
          ahb.hprot <= 4'b0011;
          
          if (ahb.hready) begin
            state <= AHB_DATA_PHASE;
            burst_count <= '0;
          end
        end

        AHB_DATA_PHASE: begin
          if (ahb.hwrite) ahb.hwdata <= active_wdata;
          
          if (ahb.hready) begin
            if (active_uncacheable || burst_count == 3) begin
              ahb.htrans <= 2'b00; // IDLE
              state <= IDLE;
            end else begin
              ahb.htrans <= 2'b11; // SEQ
              ahb.haddr <= ahb.haddr + 4;
              burst_count <= burst_count + 1;
              state <= AHB_BURST_DATA;
            end
          end
        end

        AHB_BURST_DATA: begin
          if (ahb.hwrite) ahb.hwdata <= active_wdata;
          
          if (ahb.hready) begin
            if (burst_count == 3) begin
              ahb.htrans <= 2'b00; // IDLE
              state <= IDLE;
            end else begin
              ahb.htrans <= 2'b11; // SEQ
              ahb.haddr <= ahb.haddr + 4;
              burst_count <= burst_count + 1;
            end
          end
        end

      endcase
    end
  end

endmodule
