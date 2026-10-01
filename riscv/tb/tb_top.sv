`timescale 1ns/1ps

module tb_top;
  localparam string INIT_FILE = "program.hex";
  logic clk;
  logic rst_n;

  // Clock Generation (100 MHz)
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Reset Sequence
  initial begin
    rst_n = 0;
    #20;
    rst_n = 1;
    
    // Let the simulation run for a bit
    #2000;
    
    // Print out register states
    $display("--- RISC-V CPU Simulation Complete ---");
    $display("Register x5: 0x%0h", dut.core_inst.rf_inst.registers[5]);
    $display("Register x6: 0x%0h", dut.core_inst.rf_inst.registers[6]);
    $display("Register x7: 0x%0h", dut.core_inst.rf_inst.registers[7]);
    
    // Check Cache internal state
    $display("Cache internal state at index 0x40: 0x%0h (dirty=%b, valid=%b, tag=0x%0h)", 
             dut.dcache_inst.data_array['h40], 
             dut.dcache_inst.dirty_array['h40],
             dut.dcache_inst.valid_array['h40],
             dut.dcache_inst.tag_array['h40]);

    // Print out memory states
    // 0x100 / 4 = 64 = 0x40
    // 0x500 / 4 = 320 = 0x140
    $display("SRAM Address 0x100: 0x%0h", dut.sram_inst.mem['h40]);
    $display("SRAM Address 0x500: 0x%0h", dut.sram_inst.mem['h140]);
    
    $display("Simulation timeout reached. Finishing...");
    $finish;
  end

  // DUT Instantiation
  riscv_top #(
    .BOOT_ADDR(32'h0000_0000),
    .INIT_FILE(INIT_FILE)
  ) dut (
    .clk(clk),
    .rst_n(rst_n)
  );

  // Waveform dumping (Standard VCD for GTKWave)
  initial begin
    $dumpfile("waves.vcd");
    $dumpvars(0, tb_top);
  end

endmodule