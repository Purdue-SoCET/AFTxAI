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

    // Instantiate aft_synth_top with USE_SRAM_MACRO = 1 and USE_SYNTH_ROM = 1
    aft_synth_top #(
        .USE_SRAM_MACRO(1'b1),
        .USE_SYNTH_ROM(1'b1)
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

    // Monitor real execution milestone flags
    logic saw_gpio0_dir_write = 1'b0;
    logic saw_gpio0_data_a5a5 = 1'b0;
    logic saw_sram_write = 1'b0;
    logic saw_sram_read = 1'b0;
    logic saw_gpio0_pass_5a5a = 1'b0;

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

            // Monitor GPIO0 Output Pins for architectural side effects
            if (gpio0_oe == 32'h0000_FFFF) begin
                if (!saw_gpio0_dir_write) begin
                    $display("[%0t] [CPU EXECUTION EVENT] GPIO0 Direction configured: oe=0x%08x", $time, gpio0_oe);
                    saw_gpio0_dir_write = 1'b1;
                end
            end

            if (gpio0_out == 32'h0000_A5A5) begin
                if (!saw_gpio0_data_a5a5) begin
                    $display("[%0t] [CPU EXECUTION EVENT] GPIO0 Data written: data=0x%08x", $time, gpio0_out);
                    saw_gpio0_data_a5a5 = 1'b1;
                end
            end

            if (gpio0_out == 32'h0000_5A5A) begin
                if (!saw_gpio0_pass_5a5a) begin
                    $display("[%0t] [CPU EXECUTION EVENT] CPU completed SRAM verify & signaled PASS: data=0x%08x", $time, gpio0_out);
                    saw_gpio0_pass_5a5a = 1'b1;
                end
            end

            // Monitor AHB Subordinate 1 (SRAM) transactions initiated by CPU
            if (u_soc_top.dut.sub_ports[1].HSEL && u_soc_top.dut.sub_ports[1].HREADY) begin
                if (u_soc_top.dut.sub_ports[1].HTRANS == NONSEQ || u_soc_top.dut.sub_ports[1].HTRANS == SEQ) begin
                    if (u_soc_top.dut.sub_ports[1].HWRITE) begin
                        if (!saw_sram_write) begin
                            $display("[%0t] [CPU EXECUTION EVENT] CPU initiated AHB write to SRAM: addr=0x%08x", $time, u_soc_top.dut.sub_ports[1].HADDR);
                            saw_sram_write = 1'b1;
                        end
                    end else begin
                        if (!saw_sram_read) begin
                            $display("[%0t] [CPU EXECUTION EVENT] CPU initiated AHB read from SRAM: addr=0x%08x", $time, u_soc_top.dut.sub_ports[1].HADDR);
                            saw_sram_read = 1'b1;
                        end
                    end
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

        $display("=== STARTING REAL CPU BOOT & EXECUTION INTEGRATION TEST ===");

        // Hold reset for 10 cycles
        #100;
        @(posedge clk);
        rst_n = 1;
        $display("[%0t] System reset deasserted.", $time);

        // Run simulation for up to 300 clock cycles or until pass condition is reached
        for (int cycle = 0; cycle < 300; cycle++) begin
            @(posedge clk);
            if (saw_gpio0_pass_5a5a) begin
                repeat (10) @(posedge clk);
                break;
            end
        end

        $display("----------------------------------------------------");
        $display("--- EVALUATING REAL ARCHITECTURAL EXECUTION CHECKS ---");
        $display("----------------------------------------------------");

        // Check 1: Reset Vector Fetch
        if (saw_reset_vector_fetch && captured_boot_addr == BOOT_ROM_BASE) begin
            $display("[PASS] Check 1: CPU initiated reset-vector fetch at BOOT_ROM_BASE (0x%08x)", captured_boot_addr);
            pass_count++;
        end else begin
            $display("[FAIL] Check 1: CPU reset-vector fetch failed! addr=0x%08x", captured_boot_addr);
            fail_count++;
        end

        // Check 2: Peripheral Store (GPIO0 Direction Configuration)
        if (saw_gpio0_dir_write) begin
            $display("[PASS] Check 2: CPU executed instruction stream and configured GPIO0 Direction (0x0000FFFF).");
            pass_count++;
        end else begin
            $display("[FAIL] Check 2: CPU failed to execute GPIO0 Direction configuration!");
            fail_count++;
        end

        // Check 3: Peripheral Store (GPIO0 Data Pattern 0x0000A5A5)
        if (saw_gpio0_data_a5a5) begin
            $display("[PASS] Check 3: CPU executed store to GPIO0 Data register (0x0000A5A5).");
            pass_count++;
        end else begin
            $display("[FAIL] Check 3: CPU failed to write GPIO0 Data register!");
            fail_count++;
        end

        // Check 4: SRAM Macro Bus Transaction (Write)
        if (saw_sram_write) begin
            $display("[PASS] Check 4: CPU executed store to on-chip SRAM macro via AHB bus.");
            pass_count++;
        end else begin
            $display("[FAIL] Check 4: CPU failed to issue write to on-chip SRAM!");
            fail_count++;
        end

        // Check 5: SRAM Macro Bus Transaction (Read)
        if (saw_sram_read) begin
            $display("[PASS] Check 5: CPU executed load from on-chip SRAM macro via AHB bus.");
            pass_count++;
        end else begin
            $display("[FAIL] Check 5: CPU failed to issue read from on-chip SRAM!");
            fail_count++;
        end

        // Check 6: Deterministic End-to-End Program Completion (GPIO0 == 0x00005A5A)
        if (saw_gpio0_pass_5a5a) begin
            $display("[PASS] Check 6: CPU successfully verified SRAM readback and signaled PASS (0x00005A5A)!");
            pass_count++;
        end else begin
            $display("[FAIL] Check 6: CPU failed to complete program or SRAM readback verification!");
            fail_count++;
        end

        $display("====================================================");
        $display("REAL CPU EXECUTION RESULTS: Total=%0d, Passed=%0d, Failed=%0d",
                 pass_count + fail_count, pass_count, fail_count);
        $display("====================================================");

        if (fail_count > 0) begin
            $fatal(1, "[FAIL] Real CPU execution test failed with %0d errors!", fail_count);
        end else begin
            $display("[SUCCESS] Real CPU execution and SRAM-backed SoC operation fully verified!");
            $finish;
        end
    end

endmodule
