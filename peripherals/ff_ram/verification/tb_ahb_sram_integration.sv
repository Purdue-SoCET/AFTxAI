`timescale 1ns/1ps

`include "ahb_pkg.sv"

module tb_ahb_sram_integration;
    import ahb_pkg::*;

    logic HCLK;
    logic HRESETn;

    ahb_if #(.DATA_WIDTH(32), .ADDR_WIDTH(32)) ahb_bus(.HCLK(HCLK), .HRESETn(HRESETn));
    bus_protocol_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) generic_bus();

    // 16 KiB SRAM subordinate at base address 0x0000_8000
    localparam logic [31:0] RAM_BASE = 32'h0000_8000;
    localparam int NUM_WORDS = 4096; // 16 KiB

    ahb_subordinate #(
        .BASE_ADDR(RAM_BASE),
        .NUM_WORDS(NUM_WORDS),
        .HDATA_WIDTH(32)
    ) u_subordinate (
        .HCLK(HCLK),
        .HRESETn(HRESETn),
        .ahb(ahb_bus.subordinate),
        .generic_if(generic_bus.protocol)
    );

    sky130_sram_banked_16k u_sram_banked (
        .clk(HCLK),
        .rst_n(HRESETn),
        .bus(generic_bus.peripheral_vital)
    );

    // 100 MHz clock generation
    always #5 HCLK = ~HCLK;

    int test_count = 0;
    int pass_count = 0;
    int fail_count = 0;

    task init_ahb();
        ahb_bus.HSEL = 1'b0;
        ahb_bus.HADDR = '0;
        ahb_bus.HTRANS = IDLE;
        ahb_bus.HWRITE = 1'b0;
        ahb_bus.HSIZE = WORD;
        ahb_bus.HBURST = SINGLE;
        ahb_bus.HMASTLOCK = 1'b0;
        ahb_bus.HWDATA = '0;
        ahb_bus.HWSTRB = 4'b0;
        ahb_bus.HREADY = 1'b1;
    endtask

    // AHB Write Transaction (Address Phase -> Data Phase)
    task ahb_write(input [31:0] addr, input [31:0] data, input [3:0] strb);
        @(posedge HCLK);
        #1;
        // Address Phase
        ahb_bus.HSEL   = 1'b1;
        ahb_bus.HADDR  = addr;
        ahb_bus.HTRANS = NONSEQ;
        ahb_bus.HWRITE = 1'b1;
        ahb_bus.HSIZE  = WORD;
        ahb_bus.HBURST = SINGLE;
        ahb_bus.HREADY = 1'b1;

        // Wait for subordinate to capture address
        @(posedge HCLK);
        #1;
        // Data Phase
        ahb_bus.HWDATA = data;
        ahb_bus.HWSTRB = strb;
        ahb_bus.HTRANS = IDLE;
        ahb_bus.HSEL   = 1'b0;

        // Wait until HREADYOUT is 1
        while (!ahb_bus.HREADYOUT) begin
            @(posedge HCLK);
            #1;
        end

        @(posedge HCLK);
        #1;
        init_ahb();
    endtask

    // AHB Read Transaction (Address Phase -> Data Phase with wait states)
    task ahb_read(input [31:0] addr, input [31:0] expected_data, input string test_name);
        logic [31:0] sampled_data;
        int wait_states;
        test_count++;
        wait_states = 0;

        @(posedge HCLK);
        #1;
        // Address Phase
        ahb_bus.HSEL   = 1'b1;
        ahb_bus.HADDR  = addr;
        ahb_bus.HTRANS = NONSEQ;
        ahb_bus.HWRITE = 1'b0;
        ahb_bus.HSIZE  = WORD;
        ahb_bus.HBURST = SINGLE;
        ahb_bus.HREADY = 1'b1;

        // Transition to Data Phase
        @(posedge HCLK);
        #1;
        ahb_bus.HTRANS = IDLE;
        ahb_bus.HSEL   = 1'b0;

        // While subordinate is asserting wait states (HREADYOUT == 0), count them
        while (!ahb_bus.HREADYOUT) begin
            wait_states++;
            @(posedge HCLK);
            #1;
        end

        // Data is accepted on this rising edge when HREADYOUT is 1
        sampled_data = ahb_bus.HRDATA;

        if (sampled_data === expected_data && wait_states == 2) begin
            $display("[PASS] %s at addr=0x%08x: data=0x%08x (wait_states=%0d)", test_name, addr, sampled_data, wait_states);
            pass_count++;
        end else begin
            $display("[FAIL] %s at addr=0x%08x: expected=0x%08x, got=0x%08x, wait_states=%0d (expected 2)",
                     test_name, addr, expected_data, sampled_data, wait_states);
            fail_count++;
        end

        @(posedge HCLK);
        #1;
        init_ahb();
    endtask

    initial begin
        HCLK = 0;
        HRESETn = 0;
        init_ahb();

        #25;
        HRESETn = 1;
        #15;

        $display("=== STARTING AHB-LITE TO SRAM INTEGRATION SUITE ===");

        // Test 1: Single Word Write & Read at Bank 0 Base
        begin
            logic [31:0] addr = RAM_BASE + 32'h0;
            logic [31:0] data = 32'hDEADBEEF;
            ahb_write(addr, data, 4'b1111);
            ahb_read(addr, data, "AHB_Bank0_Word");
        end

        // Test 2: Word Write & Read at Bank 1 Base (address offset 0x800)
        begin
            logic [31:0] addr = RAM_BASE + 32'h0800;
            logic [31:0] data = 32'hCAFE1234;
            ahb_write(addr, data, 4'b1111);
            ahb_read(addr, data, "AHB_Bank1_Word");
        end

        // Test 3: Byte Strobe Writes (Partial Word writes)
        begin
            logic [31:0] addr = RAM_BASE + 32'h10;
            ahb_write(addr, 32'h00000000, 4'b1111);
            ahb_write(addr, 32'h000000AA, 4'b0001); // Byte 0
            ahb_write(addr, 32'h0000BB00, 4'b0010); // Byte 1
            ahb_write(addr, 32'hCC000000, 4'b1000); // Byte 3
            ahb_read(addr, 32'hCC00BBAA, "AHB_Byte_Strobes");
        end

        // Test 4: Consecutive Reads across different banks
        begin
            logic [31:0] addr0 = RAM_BASE + 32'h0000;
            logic [31:0] addr1 = RAM_BASE + 32'h0800;
            ahb_read(addr0, 32'hDEADBEEF, "AHB_Consecutive_Read0");
            ahb_read(addr1, 32'hCAFE1234, "AHB_Consecutive_Read1");
        end

        // Test 5: Read-After-Write (RAW) on same address
        begin
            logic [31:0] addr = RAM_BASE + 32'h24;
            logic [31:0] data = 32'hA5A55A5A;
            ahb_write(addr, data, 4'b1111);
            ahb_read(addr, data, "AHB_RAW_Immediate");
        end

        // Summary
        $display("====================================================");
        $display("AHB INTEGRATION RESULTS: Total=%0d, Passed=%0d, Failed=%0d", test_count, pass_count, fail_count);
        $display("====================================================");

        if (fail_count == 0) begin
            $display("[SUCCESS] All AHB-SRAM integration tests passed!");
            $finish;
        end else begin
            $fatal(1, "[FAILURE] %0d AHB integration tests failed!", fail_count);
        end
    end

endmodule
