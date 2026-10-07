module tb_l1_cache;
  import riscv_pkg::*;
  logic clk=0, rst_n=0;
  
  cache_if cpu_if();
  coherence_if bus_if();
  bit pass = 1'b1;

  l1_cache #(
    .CACHE_SIZE(1024), .BLOCK_WORDS(4), .ASSOC(2), .CACHE_TYPE(DCACHE)
  ) dut (
    .clk(clk), .rst_n(rst_n), .cpu(cpu_if.cache), .bus(bus_if.cache)
  );

  always #5 clk = ~clk;

  always_ff @(posedge clk) begin
    bus_if.gnt <= bus_if.req; // auto-grant
  end

  initial begin
    cpu_if.req = 0; cpu_if.addr = 0; cpu_if.wdata = 0; cpu_if.wmask = 0; 
    cpu_if.we = 0; cpu_if.is_amo = 0; cpu_if.amo_op = ALU_ADD;
    
    bus_if.rvalid = 0; bus_if.rdata = 0; bus_if.rlast = 0; bus_if.rresp = 0; 
    bus_if.snoop_valid = 0; bus_if.flush_req = 0;

    rst_n = 0; #15; rst_n = 1;

    // CPU Read Miss
    @(posedge clk);
    cpu_if.req = 1; cpu_if.addr = 32'h0000_1000; cpu_if.we = 0;
    
    wait(bus_if.req == 1);
    
    // Simulate burst return
    @(posedge clk); bus_if.rvalid = 1; bus_if.rdata = 32'hCAFEBABE;
    @(posedge clk); bus_if.rdata = 32'hDEADBEEF;
    @(posedge clk); bus_if.rdata = 32'h12345678;
    @(posedge clk); bus_if.rdata = 32'h87654321; bus_if.rlast = 1;
    @(posedge clk); bus_if.rvalid = 0; bus_if.rlast = 0;
    
    wait(cpu_if.valid == 1);
    #1;
    assert(cpu_if.rdata == 32'hCAFEBABE) else begin pass = 1'b0; $error("Read Miss Fill Failed"); end
    
    // Cleanup
    @(posedge clk); cpu_if.req = 0;
    
    #20;
    if (pass) $display("PASS");
    else $display("FAIL");
    $finish;
  end
endmodule
