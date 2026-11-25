`timescale 1ns/1ps

module tb_sram_vs_ffram;

    logic clk;
    logic rst_n;

    // Instantiate two bus interfaces
    bus_protocol_if ff_bus();
    bus_protocol_if sram_bus();

    // Golden model: ff_ram with LATENCY=0
    ff_ram #(
        .NBYTES(16384),
        .ROM(1'b0),
        .LATENCY(0),
        .DATA_WIDTH(32)
    ) u_golden_ram (
        .clk(clk),
        .rst_n(rst_n),
        .bus(ff_bus.peripheral_vital)
    );

    // DUT: sky130_sram_banked_16k
    sky130_sram_banked_16k u_sram_ram (
        .clk(clk),
        .rst_n(rst_n),
        .bus(sram_bus.peripheral_vital)
    );

    // Clock generation (100 MHz, 10ns period)
    always #5 clk = ~clk;

    int test_count = 0;
    int pass_count = 0;
    int fail_count = 0;

    // Bus master driver tasks
    task init_bus();
        ff_bus.wen = 1'b0;
        ff_bus.ren = 1'b0;
        ff_bus.addr = '0;
        ff_bus.wdata = '0;
        ff_bus.strobe = '0;

        sram_bus.wen = 1'b0;
        sram_bus.ren = 1'b0;
        sram_bus.addr = '0;
        sram_bus.wdata = '0;
        sram_bus.strobe = '0;
    endtask

    // Write operation: 1 clock cycle for both!
    task do_write(input [31:0] addr, input [31:0] data, input [3:0] strb);
        @(posedge clk);
        #1;
        ff_bus.wen = 1'b1;
        ff_bus.ren = 1'b0;
        ff_bus.addr = addr;
        ff_bus.wdata = data;
        ff_bus.strobe = strb;

        sram_bus.wen = 1'b1;
        sram_bus.ren = 1'b0;
        sram_bus.addr = addr;
        sram_bus.wdata = data;
        sram_bus.strobe = strb;

        @(posedge clk);
        #1;
        init_bus();
    endtask

    // Read operation:
    // Golden ff_ram has LATENCY=0 (completes in same cycle 0).
    // SRAM macro has 1-wait-state (stalls in cycle 0 and cycle 1, completes in cycle 2).
    task do_read(input [31:0] addr, input [31:0] expected_data, input string test_name);
        logic [31:0] gold_data;
        logic [31:0] sram_data;

        test_count++;

        // Drive request at posedge clk
        @(posedge clk);
        #1;
        ff_bus.ren = 1'b1;
        ff_bus.wen = 1'b0;
        ff_bus.addr = addr;
        ff_bus.strobe = 4'b0;

        sram_bus.ren = 1'b1;
        sram_bus.wen = 1'b0;
        sram_bus.addr = addr;
        sram_bus.strobe = 4'b0;

        // Golden model completes immediately (LATENCY=0): sample rdata while ren is high
        #1;
        gold_data = ff_bus.rdata;

        // Deassert golden model bus after cycle 0 so it mimics a completed 0-wait transfer
        @(posedge clk);
        #1;
        ff_bus.ren = 1'b0;

        // Cycle 1: SRAM is in READ_WAIT (stall must be 1)
        if (sram_bus.request_stall !== 1'b1) begin
            $display("[FAIL] %s: SRAM did not maintain request_stall in cycle 1! (stall=%b)", test_name, sram_bus.request_stall);
            fail_count++;
        end

        // Wait to Cycle 2 (posedge clk - READ_DATA phase)
        @(posedge clk);
        #1;
        if (sram_bus.request_stall !== 1'b0) begin
            $display("[FAIL] %s: SRAM did not deassert request_stall in cycle 2! (stall=%b)", test_name, sram_bus.request_stall);
            fail_count++;
        end

        sram_data = sram_bus.rdata;

        if (sram_data === expected_data && gold_data === expected_data) begin
            $display("[PASS] %s at addr=0x%08x: data=0x%08x", test_name, addr, sram_data);
            pass_count++;
        end else begin
            $display("[FAIL] %s at addr=0x%08x: expected=0x%08x, got sram=0x%08x, gold=0x%08x", test_name, addr, expected_data, sram_data, gold_data);
            fail_count++;
        end

        // Master accepts data at next rising edge
        @(posedge clk);
        #1;
        init_bus();
    endtask

    initial begin
        clk = 0;
        rst_n = 0;
        init_bus();

        #25;
        rst_n = 1;
        #15;

        $display("=== STARTING SRAM VS FF_RAM EQUIVALENCE TESTSUITE ===");

        // Test 1: Bank 0 Base
        begin
            logic [31:0] test_addr = 0;
            logic [31:0] test_data = 32'hA00055AA;
            do_write(test_addr, test_data, 4'b1111);
            do_read(test_addr, test_data, "Bank_0_base");
        end

        // Tests 2-8: Test base of each remaining bank (Banks 1 to 7)
        // Each bank is 2048 bytes (0x800).
        for (int b = 1; b < 8; b++) begin
            logic [31:0] test_addr;
            logic [31:0] test_data;
            test_addr = b * 32'h800;
            test_data = 32'h11223344 ^ (b << 24) ^ (b << 16) ^ (b << 8) ^ b;
            do_write(test_addr, test_data, 4'b1111);
            do_read(test_addr, test_data, $sformatf("Bank_%0d_base", b));
        end

        // Tests 9-16: Test top word of each bank
        // Top word of bank b is at offset 0x800 - 4 = 0x7FC
        for (int b = 0; b < 8; b++) begin
            logic [31:0] test_addr;
            logic [31:0] test_data;
            test_addr = (b * 32'h800) + 32'h7FC;
            test_data = 32'hCAFE0000 | b;
            do_write(test_addr, test_data, 4'b1111);
            do_read(test_addr, test_data, $sformatf("Bank_%0d_top", b));
        end

        // Tests 17-20: Byte strobes / byte masks on Bank 0
        begin
            logic [31:0] test_addr = 32'h00000010;
            // Initialize word to 0
            do_write(test_addr, 32'h00000000, 4'b1111);
            do_read(test_addr, 32'h00000000, "Strobe_init");

            // Write byte 0
            do_write(test_addr, 32'h000000AA, 4'b0001);
            do_read(test_addr, 32'h000000AA, "Strobe_byte0");

            // Write byte 1
            do_write(test_addr, 32'h0000BB00, 4'b0010);
            do_read(test_addr, 32'h0000BBAA, "Strobe_byte1");

            // Write bytes 2 and 3
            do_write(test_addr, 32'hDEAD0000, 4'b1100);
            do_read(test_addr, 32'hDEADBBAA, "Strobe_byte2_3");
        end

        // Test 21: High 32-bit word within a 64-bit macro row (bus.addr[2] == 1)
        begin
            logic [31:0] test_addr_low  = 32'h00000020;
            logic [31:0] test_addr_high = 32'h00000024;
            do_write(test_addr_low,  32'h12345678, 4'b1111);
            do_write(test_addr_high, 32'h9ABCDEF0, 4'b1111);
            do_read(test_addr_low,   32'h12345678, "Macro_row_word_low");
            do_read(test_addr_high,  32'h9ABCDEF0, "Macro_row_word_high");
        end

        // Test 22: Back-to-back writes across different banks
        begin
            do_write(32'h00000100, 32'hAAAA0001, 4'b1111);
            do_write(32'h00000900, 32'hBBBB0002, 4'b1111);
            do_write(32'h00001100, 32'hCCCC0003, 4'b1111);
            do_read(32'h00000100,  32'hAAAA0001, "B2B_write_bank0");
            do_read(32'h00000900,  32'hBBBB0002, "B2B_write_bank1");
            do_read(32'h00001100,  32'hCCCC0003, "B2B_write_bank2");
        end

        // Test 23: Back-to-back reads across different banks
        begin
            do_read(32'h00000100,  32'hAAAA0001, "B2B_read_bank0");
            do_read(32'h00000900,  32'hBBBB0002, "B2B_read_bank1");
            do_read(32'h00001100,  32'hCCCC0003, "B2B_read_bank2");
        end

        // Test 24: Write-then-immediate-read on same address
        begin
            logic [31:0] test_addr = 32'h00000050;
            logic [31:0] test_data = 32'h12344321;
            do_write(test_addr, test_data, 4'b1111);
            do_read(test_addr, test_data, "Write_immediate_read");
        end

        // Test 25: Reset behavior (write, assert reset, check state transitions back to IDLE)
        begin
            logic [31:0] test_addr = 32'h00000040;
            do_write(test_addr, 32'h5555AAAA, 4'b1111);
            // Assert rst_n for 2 clock cycles
            @(posedge clk);
            rst_n = 0;
            @(posedge clk);
            @(posedge clk);
            rst_n = 1;
            @(posedge clk);
            // SRAM wrapper state should be IDLE, request_stall should be 0
            if (sram_bus.request_stall !== 1'b0) begin
                $display("[FAIL] Reset: SRAM request_stall not 0 after reset!");
                fail_count++;
            end else begin
                $display("[PASS] Reset: SRAM successfully reset to IDLE");
                pass_count++;
            end
            test_count++;
        end

        // Summary
        $display("====================================================");
        $display("TEST RESULTS: Total = %0d, Passed = %0d, Failed = %0d", test_count, pass_count, fail_count);
        $display("====================================================");

        if (fail_count == 0) begin
            $display("[SUCCESS] All equivalence tests passed perfectly!");
            $finish;
        end else begin
            $fatal(1, "[FAILURE] %0d tests failed!", fail_count);
        end
    end

endmodule
