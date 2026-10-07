module tb_top;
  import uvm_pkg::*;
  import riscv_pkg::*;
  `include "uvm_macros.svh"

  logic clk;
  logic rst_n;

  // Clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Reset generation
  initial begin
    rst_n = 0;
    #20 rst_n = 1;
  end

  // Interface instance
  riscv_if vif(clk, rst_n);

  // Dummy DUT response for ack: Just acknowledge requests automatically
  always @(posedge clk) begin
    if (!rst_n) vif.ack <= 0;
    else vif.ack <= vif.req;
  end

  initial begin
    // Register Interface in Config DB
    uvm_config_db#(virtual riscv_if)::set(null, "*", "vif", vif);
    
    // Start UVM Test
    run_test("riscv_test");
  end
endmodule