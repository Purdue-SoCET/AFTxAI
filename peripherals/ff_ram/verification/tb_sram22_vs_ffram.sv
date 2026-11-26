`timescale 1ns/1ps

module tb_sram22_vs_ffram;

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

    // DUT: sram22_sram_banked_16k
    sram22_sram_banked_16k u_sram_ram (
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

    task write_word(input [31:0] addr, input [31:0] data, input [3:0] strb = 4'hF);
        @(negedge clk);
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

    task read_and_check(input [31:0] addr, input string msg);
        logic [31:0] golden_data;
        logic [31:0] sram_data;
        int stall_cycles;

        test_count++;

        // Initiate read on both
        @(negedge clk);
        ff_bus.ren = 1'b1;
        ff_bus.wen = 1'b0;
        ff_bus.addr = addr;

        sram_bus.ren = 1'b1;
        sram_bus.wen = 1'b0;
        sram_bus.addr = addr;

        // Golden model completes in 1 cycle
        @(posedge clk);
        #1;
        golden_data = ff_bus.rdata;
        ff_bus.ren = 1'b0;

        // Wait for SRAM wrapper handshake (request_stall should drop when data is ready)
        stall_cycles = 0;
        while (sram_bus.request_stall) begin
            stall_cycles++;
            @(posedge clk);
            #1;
            if (stall_cycles > 10) begin
                $display("[FAIL] Timeout waiting for sram_bus.request_stall to deassert at addr 0x%08h (%s)", addr, msg);
                fail_count++;
                return;
            end
        end

        sram_data = sram_bus.rdata;
        @(negedge clk);
        sram_bus.ren = 1'b0;

        // Compare outputs
        if (sram_data === golden_data) begin
            $display("[PASS] %s (addr: 0x%08h, data: 0x%08h, latency: %0d clk)", msg, addr, sram_data, stall_cycles);
            pass_count++;
        end else begin
            $display("[FAIL] %s (addr: 0x%08h) - Expected: 0x%08h, Got: 0x%08h", msg, addr, golden_data, sram_data);
            fail_count++;
        end
    endtask

    initial begin
        $display("============================================================");
        $display(" Starting SRAM22 vs FF-RAM Functional Equivalence Regression");
        $display("============================================================");

        clk = 0;
        rst_n = 0;
        init_bus();

        // Reset pulse
        #20;
        @(negedge clk);
        rst_n = 1;
        #10;

        // Test 1: Bank 0 word write/read
        write_word(32'h0000_0000, 32'hDEAD_BEEF);
        read_and_check(32'h0000_0000, "Bank 0 Word 0 RW");

        // Test 2: Bank 0 word 1
        write_word(32'h0000_0004, 32'hCAFE_BABE);
        read_and_check(32'h0000_0004, "Bank 0 Word 1 RW");

        // Test 3: Byte writes (strobe testing)
        write_word(32'h0000_0008, 32'h1122_3344, 4'b0001); // write byte 0
        write_word(32'h0000_0008, 32'h5566_7788, 4'b0010); // write byte 1
        write_word(32'h0000_0008, 32'h99AA_BBCC, 4'b1100); // write bytes 2,3
        read_and_check(32'h0000_0008, "Bank 0 Byte Strobes RW");

        // Test 4: Write to all 8 banks
        for (int b = 0; b < 8; b++) begin
            logic [31:0] test_addr = (b << 11) | 32'h0010;
            logic [31:0] test_val  = 32'hA000_0000 | (b << 16) | b;
            write_word(test_addr, test_val);
            read_and_check(test_addr, $sformatf("Bank %0d Target RW", b));
        end

        // Test 5: Verify upper 32-bit of 64-bit row across banks
        for (int b = 0; b < 8; b++) begin
            logic [31:0] test_addr = (b << 11) | 32'h0014;
            logic [31:0] test_val  = 32'hB000_0000 | (b << 16) | b;
            write_word(test_addr, test_val);
            read_and_check(test_addr, $sformatf("Bank %0d Upper Word RW", b));
        end

        // Test 6: Cross-bank back-to-back sequential reads
        for (int b = 0; b < 8; b++) begin
            logic [31:0] test_addr = (b << 11) | 32'h0010;
            read_and_check(test_addr, $sformatf("Cross-bank Seq Read Bank %0d", b));
        end

        $display("============================================================");
        $display(" Regression Completed: %0d Tests, %0d Passed, %0d Failed", test_count, pass_count, fail_count);
        $display("============================================================");

        if (fail_count == 0) begin
            $display("[SUCCESS] All SRAM22 functional equivalence tests passed!");
            $finish;
        end else begin
            $display("[FAILURE] SRAM22 functional regression failed.");
            $fatal(1);
        end
    end

endmodule
