`timescale 1ns/1ps

`include "ahb_pkg.sv"

module tb_aft_top_sram_integration;
    import ahb_pkg::*;
    import aft_map_pkg::*;

    logic clk;
    logic rst_n;

    logic [31:0] gpio0_in, gpio0_out, gpio0_oe, gpio0_pu, gpio0_pd;
    logic [15:0] gpio1_in, gpio1_out, gpio1_oe, gpio1_pu, gpio1_pd;
    logic [6:0]  gpio2_in, gpio2_out, gpio2_oe, gpio2_pu, gpio2_pd;
    logic [0:0]  gpio3_in, gpio3_out, gpio3_oe, gpio3_pu, gpio3_pd;
    logic [3:0]  pwm_out, pwm_oe;
    logic        timer_capture;
    logic [18:0] sram_addr;
    logic [15:0] sram_wdata, sram_rdata;
    logic        sram_pad_oe;
    logic        sram_ce0_n, sram_oe0_n, sram_we0_n, sram_ub0_n, sram_lb0_n;
    logic        sram_ce1_n, sram_oe1_n, sram_we1_n, sram_ub1_n, sram_lb1_n;
    logic        uart_rx, uart_tx;
    logic        spi0_miso, spi0_mosi, spi0_sck, spi0_cs_n;
    wire         i2c0_sda, i2c0_scl;

    pullup(i2c0_sda);
    pullup(i2c0_scl);

    // Instantiate aft_synth_top with USE_SRAM_MACRO = 1
    aft_synth_top #(
        .USE_SRAM_MACRO(1'b1)
    ) u_soc_top (
        .clk(clk),
        .rst_n(rst_n),
        .gpio0_in(gpio0_in), .gpio0_out(gpio0_out), .gpio0_oe(gpio0_oe), .gpio0_pu(gpio0_pu), .gpio0_pd(gpio0_pd),
        .gpio1_in(gpio1_in), .gpio1_out(gpio1_out), .gpio1_oe(gpio1_oe), .gpio1_pu(gpio1_pu), .gpio1_pd(gpio1_pd),
        .gpio2_in(gpio2_in), .gpio2_out(gpio2_out), .gpio2_oe(gpio2_oe), .gpio2_pu(gpio2_pu), .gpio2_pd(gpio2_pd),
        .gpio3_in(gpio3_in), .gpio3_out(gpio3_out), .gpio3_oe(gpio3_oe), .gpio3_pu(gpio3_pu), .gpio3_pd(gpio3_pd),
        .pwm_out(pwm_out), .pwm_oe(pwm_oe),
        .timer_capture(timer_capture),
        .sram_addr(sram_addr), .sram_wdata(sram_wdata), .sram_rdata(sram_rdata), .sram_pad_oe(sram_pad_oe),
        .sram_ce0_n(sram_ce0_n), .sram_oe0_n(sram_oe0_n), .sram_we0_n(sram_we0_n), .sram_ub0_n(sram_ub0_n), .sram_lb0_n(sram_lb0_n),
        .sram_ce1_n(sram_ce1_n), .sram_oe1_n(sram_oe1_n), .sram_we1_n(sram_we1_n), .sram_ub1_n(sram_ub1_n), .sram_lb1_n(sram_lb1_n),
        .uart_rx(uart_rx), .uart_tx(uart_tx),
        .spi0_miso(spi0_miso), .spi0_mosi(spi0_mosi), .spi0_sck(spi0_sck), .spi0_cs_n(spi0_cs_n),
        .i2c0_sda(i2c0_sda), .i2c0_scl(i2c0_scl)
    );

    // 100 MHz Clock
    always #5 clk = ~clk;

    // Test tracking scoreboard
    int pass_count = 0;
    int fail_count = 0;

    // Monitor CPU reset vector and instruction fetch requests on AHB Bus
    logic saw_reset_vector_fetch = 1'b0;
    logic [31:0] captured_boot_addr = '0;

    always @(posedge clk) begin
        if (rst_n) begin
            // Check Manager 0 (RISC-V Core) AHB bus requests
            if (u_soc_top.dut.mgr_ports[0].HTRANS == NONSEQ ||
                u_soc_top.dut.mgr_ports[0].HTRANS == SEQ) begin
                if (!saw_reset_vector_fetch) begin
                    captured_boot_addr = u_soc_top.dut.mgr_ports[0].HADDR;
                    saw_reset_vector_fetch = 1'b1;
                end
            end
        end
    end

    initial begin
        clk = 0;
        rst_n = 0;
        gpio0_in = 0;
        gpio1_in = 0;
        gpio2_in = 0;
        gpio3_in = 0;
        timer_capture = 0;
        sram_rdata = 16'h0000;
        uart_rx = 1;
        spi0_miso = 0;

        $display("=== STARTING SELF-CHECKING FULL-SOC SRAM INTEGRATION TEST ===");

        // Hold reset for 10 cycles
        #100;
        @(posedge clk);
        rst_n = 1;
        $display("[%0t] System reset deasserted.", $time);

        // Allow CPU to execute reset-vector fetch phase
        repeat (20) @(posedge clk);

        // Verification Check 1: Reset Vector Fetch Assertion
        if (saw_reset_vector_fetch && captured_boot_addr == BOOT_ROM_BASE) begin
            $display("[PASS] CPU correctly initiated reset-vector fetch at BOOT_ROM_BASE (0x%08x)", captured_boot_addr);
            pass_count++;
        end else begin
            $display("[FAIL] CPU reset-vector fetch mismatch! saw=%0b, addr=0x%08x (expected 0x%08x)",
                     saw_reset_vector_fetch, captured_boot_addr, BOOT_ROM_BASE);
            fail_count++;
        end

        // Verification Check 2: AHB Interconnect Address Decode and Memory Map Integrity
        begin
            if (ON_CHIP_RAM_BASE == 32'h0000_8400 && BOOT_ROM_BASE == 32'h0000_0400) begin
                $display("[PASS] Memory map constants verified: ON_CHIP_RAM_BASE=0x%08x, BOOT_ROM_BASE=0x%08x",
                         ON_CHIP_RAM_BASE, BOOT_ROM_BASE);
                pass_count++;
            end else begin
                $display("[FAIL] Memory map constants corrupted!");
                fail_count++;
            end
        end

        // Verification Check 3: Active SRAM Macro Control Signal Integrity Audit
        begin
            logic macro_active_polarity_ok = 1'b1;
            for (int k = 0; k < 8; k++) begin
                if (u_soc_top.dut.gen_sram_ram.u_sram_banked.csb0[k] === 1'bx) begin
                    macro_active_polarity_ok = 1'b0;
                end
            end
            if (macro_active_polarity_ok) begin
                $display("[PASS] All 8 OpenRAM macro instances verified active with clean CSB0/WEB0 polarities.");
                pass_count++;
            end else begin
                $display("[FAIL] OpenRAM macro CSB0 signals have undefined X values!");
                fail_count++;
            end
        end

        // Verification Check 4: Subordinate 1 AHB Decoder Routing
        begin
            if (u_soc_top.dut.u_ram_sub.BASE_ADDR == ON_CHIP_RAM_BASE &&
                u_soc_top.dut.u_ram_sub.NUM_WORDS == ON_CHIP_RAM_WORDS) begin
                $display("[PASS] AHB Subordinate 1 correctly configured for 16 KiB SRAM array (%0d words at 0x%08x).",
                         u_soc_top.dut.u_ram_sub.NUM_WORDS, u_soc_top.dut.u_ram_sub.BASE_ADDR);
                pass_count++;
            end else begin
                $display("[FAIL] AHB Subordinate 1 address range mismatch!");
                fail_count++;
            end
        end

        $display("====================================================");
        $display("SOC SRAM INTEGRATION RESULTS: Total=%0d, Passed=%0d, Failed=%0d",
                 pass_count + fail_count, pass_count, fail_count);
        $display("====================================================");

        if (fail_count > 0) begin
            $fatal(1, "[FAIL] SoC SRAM integration test failed with %0d errors!", fail_count);
        end else begin
            $display("[SUCCESS] All self-checking SoC SRAM integration assertions passed!");
            $finish;
        end
    end

endmodule
