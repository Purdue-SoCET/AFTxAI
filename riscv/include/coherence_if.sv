import riscv_pkg::*;

interface coherence_if;
  // Cache to Memory Controller
  logic        req;
  logic [31:0] addr;
  bus_cmd_t    cmd;
  logic        uncacheable;

  // Memory Controller to Cache
  logic        gnt;

  // Data Phase (Cache -> MC)
  logic        wvalid;
  logic [31:0] wdata;
  logic        wlast;

  // Data Phase (MC -> Cache)
  logic        rvalid;
  logic [31:0] rdata;
  logic        rlast;
  logic        rresp; // 1 for AHB error

  // Snoop Broadcast (MC -> Cache)
  logic        snoop_valid;
  bus_cmd_t    snoop_cmd;
  logic [31:0] snoop_addr;

  // Snoop Response (Cache -> MC)
  logic        snoop_hit;
  logic        snoop_dirty;
  logic        snoop_ack;

  // Cache Control
  logic        flush_req;
  logic        flush_done;

  modport cache (
    output req, addr, cmd, uncacheable, wvalid, wdata, wlast, snoop_hit, snoop_dirty, snoop_ack, flush_done,
    input  gnt, rvalid, rdata, rlast, rresp, snoop_valid, snoop_cmd, snoop_addr, flush_req
  );

  modport mc (
    input  req, addr, cmd, uncacheable, wvalid, wdata, wlast, snoop_hit, snoop_dirty, snoop_ack, flush_done,
    output gnt, rvalid, rdata, rlast, rresp, snoop_valid, snoop_cmd, snoop_addr, flush_req
  );
endinterface
