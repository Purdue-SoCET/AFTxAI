import riscv_pkg::*;

module tb_soc;

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

  // AHB Interface
  ahb_if ahb_m();

  // Instantiate RISC-V Cluster
  riscv_cluster dut (
    .clk(clk),
    .rst_n(rst_n),
    .ahb_m(ahb_m)
  );

  // AHB Memory Model
  localparam MEM_SIZE = 65536; // 64KB
  logic [31:0] memory [0:MEM_SIZE/4-1];

  // Load memory from hex file
  initial begin
    for (int i = 0; i < MEM_SIZE/4; i++) memory[i] = 32'h0;
    $readmemh("../tests/asm/test_quicksort.hex", memory);
  end

  // AHB slave logic
  logic [31:0] haddr_reg;
  logic hwrite_reg;
  logic hsel;

  assign hsel = (ahb_m.htrans == 2'b10 || ahb_m.htrans == 2'b11);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      haddr_reg <= 32'h0;
      hwrite_reg <= 1'b0;
    end else if (ahb_m.hready && hsel) begin
      haddr_reg <= ahb_m.haddr;
      hwrite_reg <= ahb_m.hwrite;
    end
  end

  always_ff @(posedge clk) begin
    if (ahb_m.hready && hwrite_reg) begin
      if (haddr_reg == 32'h8000) begin
        // Completion signal
        if (ahb_m.hwdata == 32'h1) begin
          $display("Program finished. Checking sorted array...");
          check_array();
          $finish;
        end
      end else begin
        // We assume aligned 32-bit accesses for simplicity
        memory[haddr_reg[15:2]] <= ahb_m.hwdata;
      end
    end
  end

  assign ahb_m.hrdata = memory[haddr_reg[15:2]];
  assign ahb_m.hready = 1'b1;
  assign ahb_m.hresp = 1'b0;

  // Task to check if array is sorted
  task check_array;
    int prev;
    int curr;
    int i;
    int fail;
    fail = 0;
    
    // Array is loaded at 0x1000, which is index 0x1000/4 = 1024
    prev = memory[1024];
    $display("Array[0] = %0d", prev);
    for (i = 1; i < 10; i++) begin
      curr = memory[1024 + i];
      $display("Array[%0d] = %0d", i, curr);
      if (curr < prev) begin
        fail = 1;
        $display("FAIL: Array not sorted at index %0d: %0d < %0d", i, curr, prev);
      end
      prev = curr;
    end
    
    if (fail)
      $display("TEST FAILED");
    else
      $display("TEST PASSED");
  endtask

  // Timeout
  initial begin
    #100000;
    $display("TEST FAILED: Timeout");
    $finish;
  end

endmodule