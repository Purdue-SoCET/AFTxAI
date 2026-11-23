`timescale 1ns/1ps

module top_tb;
    import aft_map_pkg::*;

    // Clock and Reset
    logic clk;
    logic rst_n;

    // Clock generation
    initial begin
        // $monitor("[%0t] clk=%b rst_n=%b", $time, clk, rst_n);
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end

    // Reset generation
    initial begin
        rst_n = 0;
        #100;
        rst_n = 1;
        $display("[%0t] System reset deasserted in reset block.", $time);
        $fflush();
    end

    // Peripheral I/O dummy signals
    logic [31:0] gpio0_in, gpio0_out, gpio0_oe, gpio0_pu, gpio0_pd;
    logic [15:0] gpio1_in, gpio1_out, gpio1_oe, gpio1_pu, gpio1_pd;
    logic [6:0]  gpio2_in, gpio2_out, gpio2_oe, gpio2_pu, gpio2_pd;
    logic [0:0]  gpio3_in, gpio3_out, gpio3_oe, gpio3_pu, gpio3_pd;
    logic [3:0]  pwm_out, pwm_oe;
    logic timer_capture;

    assign gpio0_in = '0;
    assign gpio1_in = '0;
    assign gpio2_in = '0;
    assign gpio3_in = '0;
    assign timer_capture = 1'b0;

    sram_if #(.ADDR_WIDTH(19)) sram();

    // Instantiate Top Level SoC
    wire i2c0_sda;
    wire i2c0_scl;
    pullup(i2c0_sda);
    pullup(i2c0_scl);

    aft_top dut (
        .clk(clk),
        .rst_n(rst_n),
        
        .gpio0_in(gpio0_in), .gpio0_out(gpio0_out), .gpio0_oe(gpio0_oe), .gpio0_pu(gpio0_pu), .gpio0_pd(gpio0_pd),
        .gpio1_in(gpio1_in), .gpio1_out(gpio1_out), .gpio1_oe(gpio1_oe), .gpio1_pu(gpio1_pu), .gpio1_pd(gpio1_pd),
        .gpio2_in(gpio2_in), .gpio2_out(gpio2_out), .gpio2_oe(gpio2_oe), .gpio2_pu(gpio2_pu), .gpio2_pd(gpio2_pd),
        .gpio3_in(gpio3_in), .gpio3_out(gpio3_out), .gpio3_oe(gpio3_oe), .gpio3_pu(gpio3_pu), .gpio3_pd(gpio3_pd),
        
        .pwm_out(pwm_out), .pwm_oe(pwm_oe),
        .timer_capture(timer_capture),
        .sram(sram.controller),
        
        .uart_rx(1'b1),
        .uart_tx(),
        
        .spi0_miso(1'b0),
        .spi0_mosi(),
        .spi0_sck(),
        .spi0_cs_n(),
        
        .i2c0_sda(i2c0_sda),
        .i2c0_scl(i2c0_scl)
    );

    string test_file;

    // Test sequence
    initial begin
        // Wait for reset to deassert
        @(posedge rst_n);
        $display("[%0t] System reset deasserted. Starting simulation...", $time);

        // Load software hex into Boot ROM
        if ($value$plusargs("test_hex=%s", test_file)) begin
            $display("[%0t] Loading hex file: %s", $time, test_file);
            $readmemh(test_file, dut.u_boot_rom.mem);
        end else begin
            $display("[%0t] WARNING: No test_hex provided. Running without software load.", $time);
        end

        // Timeout mechanism
        $dumpfile("top_tb.vcd");
        $dumpvars(0, top_tb);
        fork
            begin
                // Simulated Test Timeout
                #5000000;
                $display("[%0t] ERROR: Test Timeout!", $time);
                $finish;
            end
            begin
                forever begin
                    @(posedge clk);
                    if ($time < 10000) begin
//                        $display("[%0t] DP ICACHE VALID=%b ADDR=%h", $time, dut.u_core.dp_inst.port.icache_valid, dut.u_core.dp_inst.port.icache_addr);
                    end
                end
            end
            begin
                // Monitor for software completion via snooping CPU dcache requests
                forever begin
                    @(posedge clk);
                    
                    // D-cache valid write to PRINTER_BASE
                    if (dut.u_core.dp_if.dcache_valid && dut.u_core.dp_if.dcache_wstrb != 4'b0000 && dut.u_core.dp_if.dcache_addr == PRINTER_BASE) begin

                        if (dut.u_core.dp_if.dcache_wdata == 32'h1) begin
                            $display("[%0t] Test Passed (Software signaled success)", $time);
                            $finish;
                        end else if (dut.u_core.dp_if.dcache_wdata == 32'hBAD) begin
                            $display("[%0t] Test Failed (Software signaled failure: BAD)", $time);
                            $finish;
                        end else begin
                            $display("[%0t] Printer Write: %h (%0d)", $time, dut.u_core.dp_if.dcache_wdata, dut.u_core.dp_if.dcache_wdata);
                        end
                    end
                end
            end
        join_any
        
        $finish;
    end

    always_ff @(posedge clk) begin
        if (dut.u_core.dp_if.dcache_error) begin
            $display("[%0t] DCACHE_ERROR! dcache_valid=%b addr=%h", $time, dut.u_core.dp_if.dcache_valid, dut.u_core.dp_if.dcache_addr);
        end
        if (dut.u_core.dp_if.icache_error) begin
            $display("[%0t] ICACHE_ERROR! icache_valid=%b addr=%h", $time, dut.u_core.dp_if.icache_valid, dut.u_core.dp_if.icache_addr);
        end
    end

endmodule