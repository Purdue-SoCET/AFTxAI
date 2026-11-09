`timescale 1ns/1ps

module top_tb;
    import aft_map_pkg::*;

    // Clock and Reset
    logic clk;
    logic rst_n;

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end

    // Reset generation
    initial begin
        rst_n = 0;
        #100;
        rst_n = 1;
    end

    // Placeholder Top Level SoC Instance
    // TODO: Update instantiation when top_level RTL is complete
    /*
    top_level dut (
        .clk  (clk),
        .rst_n(rst_n)
        // ... peripheral I/O ...
    );
    */

    string test_file;

    // Test sequence
    initial begin
        // Wait for reset to deassert
        @(posedge rst_n);
        $display("[%0t] System reset deasserted. Starting simulation...", $time);

        // Load software hex into Boot ROM / RAM
        if ($value$plusargs("test_hex=%s", test_file)) begin
            $display("[%0t] Loading hex file: %s", $time, test_file);
            // Example of loading memory, assumes a memory array exists in the DUT
            // $readmemh(test_file, dut.boot_rom.mem_array);
        end else begin
            $display("[%0t] WARNING: No test_hex provided. Running without software load.", $time);
        end

        // Timeout mechanism
        fork
            begin
                // Simulated Test Timeout
                #100000;
                $display("[%0t] ERROR: Test Timeout!", $time);
                $finish;
            end
            begin
                // Monitor for software completion via a mock memory-mapped printer port
                // In a real DUT, you could snoop the AHB/APB bus or wait for a specific 
                // write to PRINTER_BASE (0xB0000000)
                /*
                forever begin
                    @(posedge clk);
                    if (dut.ahb_bus.haddr == PRINTER_BASE && dut.ahb_bus.hwrite && dut.ahb_bus.hready) begin
                        if (dut.ahb_bus.hwdata == 32'h1)
                            $display("[%0t] Test Passed (Software signaled success)", $time);
                        else
                            $display("[%0t] Test Failed (Software signaled failure: %h)", $time, dut.ahb_bus.hwdata);
                        $finish;
                    end
                end
                */
            end
        join_any
        
        $finish;
    end

    // VCD Dump
    initial begin
        $dumpfile("top_tb.vcd");
        $dumpvars(0, top_tb);
    end

endmodule
