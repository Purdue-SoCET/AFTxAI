import riscv_pkg::*;

module riscv_cluster (
  input  logic clk,
  input  logic rst_n,

  // Top level AHB Master to the system interconnect
  ahb_if.master ahb_m
);

  // --------------------------------------------------------------------------
  // Reset Synchronizer
  // --------------------------------------------------------------------------
  logic rst_sync_1, rst_sync_n;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rst_sync_1 <= 1'b0;
      rst_sync_n <= 1'b0;
    end else begin
      rst_sync_1 <= 1'b1;
      rst_sync_n <= rst_sync_1;
    end
  end

  // --------------------------------------------------------------------------
  // Core 0
  // --------------------------------------------------------------------------
  cache_if     core0_icache_if();
  cache_if     core0_dcache_if();
  coherence_if core0_icache_bus();
  coherence_if core0_dcache_bus();

  datapath #(
    .HART_ID(0), .RV32E(RV32E), .EXT_A(EXT_A)
  ) core0 (
    .clk(clk), .rst_n(rst_sync_n),
    .icache(core0_icache_if.cpu),
    .dcache(core0_dcache_if.cpu)
`ifdef RISCV_TRACE
    , .trace_pc(), .trace_instr(), .trace_rd_addr(), .trace_rd_wdata(), 
    .trace_rd_we(), .trace_mem_addr(), .trace_mem_wdata(), .trace_mem_wmask(), .trace_trap()
`endif
  );

  l1_cache #(
    .CACHE_SIZE(1024), .BLOCK_WORDS(4), .ASSOC(2), .CACHE_TYPE(ICACHE)
  ) icache0 (
    .clk(clk), .rst_n(rst_sync_n),
    .cpu(core0_icache_if.cache),
    .bus(core0_icache_bus.cache)
  );

  l1_cache #(
    .CACHE_SIZE(1024), .BLOCK_WORDS(4), .ASSOC(2), .CACHE_TYPE(DCACHE)
  ) dcache0 (
    .clk(clk), .rst_n(rst_sync_n),
    .cpu(core0_dcache_if.cache),
    .bus(core0_dcache_bus.cache)
  );

  // --------------------------------------------------------------------------
  // Core 1
  // --------------------------------------------------------------------------
  cache_if     core1_icache_if();
  cache_if     core1_dcache_if();
  coherence_if core1_icache_bus();
  coherence_if core1_dcache_bus();

  datapath #(
    .HART_ID(1), .RV32E(RV32E), .EXT_A(EXT_A)
  ) core1 (
    .clk(clk), .rst_n(rst_sync_n),
    .icache(core1_icache_if.cpu),
    .dcache(core1_dcache_if.cpu)
`ifdef RISCV_TRACE
    , .trace_pc(), .trace_instr(), .trace_rd_addr(), .trace_rd_wdata(), 
    .trace_rd_we(), .trace_mem_addr(), .trace_mem_wdata(), .trace_mem_wmask(), .trace_trap()
`endif
  );

  l1_cache #(
    .CACHE_SIZE(1024), .BLOCK_WORDS(4), .ASSOC(2), .CACHE_TYPE(ICACHE)
  ) icache1 (
    .clk(clk), .rst_n(rst_sync_n),
    .cpu(core1_icache_if.cache),
    .bus(core1_icache_bus.cache)
  );

  l1_cache #(
    .CACHE_SIZE(1024), .BLOCK_WORDS(4), .ASSOC(2), .CACHE_TYPE(DCACHE)
  ) dcache1 (
    .clk(clk), .rst_n(rst_sync_n),
    .cpu(core1_dcache_if.cache),
    .bus(core1_dcache_bus.cache)
  );

  // --------------------------------------------------------------------------
  // Memory Controller
  // --------------------------------------------------------------------------
  memory_controller mc (
    .clk(clk),
    .rst_n(rst_sync_n),
    .icache0(core0_icache_bus.mc),
    .dcache0(core0_dcache_bus.mc),
    .icache1(core1_icache_bus.mc),
    .dcache1(core1_dcache_bus.mc),
    .ahb(ahb_m)
  );

endmodule
