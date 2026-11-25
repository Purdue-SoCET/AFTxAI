`timescale 1ns/1ps

module tb_l1_cache_direct;
    logic HCLK;
    logic nRST;

    cpu_cache_if cpu_if();
    cache_bus_if bus_if();
    l1_cache_if port_unused();

    // DUT instantiation: 1KB write-back data cache (direct-mapped, 16B block)
    l1_cache #(
        .CACHE_SIZE(1024),
        .BLOCK_SIZE(4),
        .ASSOCIATIVITY(1),
        .CACHE_TYPE(1)
    ) dut (
        .HCLK(HCLK),
        .nRST(nRST),
        .cpu_if(cpu_if.cache),
        .bus_if(bus_if.cache),
        .port_unused(port_unused.mp)
    );

    // 100 MHz clock
    always #5 HCLK = ~HCLK;

    int pass_count = 0;
    int fail_count = 0;

    // Emulated Bus Controller memory (32KB backing store)
    logic [31:0] backing_mem [8192];

    // Bus controller FSM responder for fills and evictions
    initial begin
        bus_if.gnt   = 0;
        bus_if.valid = 0;
        bus_if.last  = 0;
        bus_if.rdata = 0;
        bus_if.error = 0;

        for (int i = 0; i < 8192; i++) begin
            backing_mem[i] = 32'h1000_0000 + i;
        end

        forever begin
            @(posedge HCLK);
            if (!nRST) begin
                bus_if.gnt <= 0;
                bus_if.valid <= 0;
                bus_if.last <= 0;
            end else begin
                // Handle request
                if (bus_if.req && !bus_if.gnt) begin
                    // Grant on next cycle
                    bus_if.gnt <= 1;
                    if (bus_if.rnw) begin
                        // Refill burst of 4 words
                        automatic logic [31:0] base_idx = bus_if.addr[14:2] & ~32'd3;
                        @(posedge HCLK);
                        bus_if.gnt <= 0;
                        for (int w = 0; w < 4; w++) begin
                            bus_if.valid <= 1;
                            bus_if.rdata <= backing_mem[base_idx + w];
                            bus_if.last  <= (w == 3);
                            @(posedge HCLK);
                        end
                        bus_if.valid <= 0;
                        bus_if.last  <= 0;
                    end else begin
                        // Eviction burst of 4 words
                        automatic logic [31:0] base_idx = bus_if.addr[14:2] & ~32'd3;
                        @(posedge HCLK);
                        bus_if.gnt <= 0;
                        for (int w = 0; w < 4; w++) begin
                            bus_if.valid <= 1;
                            bus_if.last  <= (w == 3);
                            backing_mem[base_idx + w] = bus_if.wdata;
                            @(posedge HCLK);
                        end
                        bus_if.valid <= 0;
                        bus_if.last  <= 0;
                    end
                end
            end
        end
    end

    // Task for CPU Read
    task automatic cpu_read(input logic [31:0] addr, output logic [31:0] data);
        cpu_if.addr  <= addr;
        cpu_if.valid <= 1;
        cpu_if.wstrb <= 4'b0000;
        cpu_if.wdata <= 32'b0;
        @(posedge HCLK);
        while (!cpu_if.ready) begin
            @(posedge HCLK);
        end
        data = cpu_if.rdata;
        cpu_if.valid <= 0;
        @(posedge HCLK);
    endtask

    // Task for CPU Write
    task automatic cpu_write(input logic [31:0] addr, input logic [31:0] data, input logic [3:0] strb);
        cpu_if.addr  <= addr;
        cpu_if.valid <= 1;
        cpu_if.wstrb <= strb;
        cpu_if.wdata <= data;
        @(posedge HCLK);
        while (!cpu_if.ready) begin
            @(posedge HCLK);
        end
        // When hit and ready, write commits on this clock edge
        @(posedge HCLK);
        cpu_if.valid <= 0;
        cpu_if.wstrb <= 4'b0000;
        @(posedge HCLK);
    endtask

    initial begin
        logic [31:0] rdata;
        HCLK = 0;
        nRST = 0;
        cpu_if.valid = 0;
        cpu_if.addr  = 0;
        cpu_if.wdata = 0;
        cpu_if.wstrb = 0;

        $display("=== STARTING FOCUSED L1 CACHE UNIT REGRESSION ===");
        #40;
        @(posedge HCLK);
        nRST = 1;
        repeat (5) @(posedge HCLK);

        // Test 1: Cold Miss and Refill
        $display("[TEST 1] Read miss at 0x00000100 (Set 16, Word 0)");
        cpu_read(32'h0000_0100, rdata);
        if (rdata == backing_mem[32'h0000_0100 >> 2]) begin
            $display("[PASS] Test 1: Miss returned correct backing memory data: 0x%08x", rdata);
            pass_count++;
        end else begin
            $display("[FAIL] Test 1: Expected 0x%08x, got 0x%08x", backing_mem[32'h0000_0100 >> 2], rdata);
            fail_count++;
        end

        // Test 2: Cache Hit on Refilled Line (different word in same block)
        $display("[TEST 2] Cache hit at 0x00000104 (Set 16, Word 1)");
        cpu_read(32'h0000_0104, rdata);
        if (rdata == backing_mem[32'h0000_0104 >> 2]) begin
            $display("[PASS] Test 2: Hit on word 1 returned: 0x%08x", rdata);
            pass_count++;
        end else begin
            $display("[FAIL] Test 2: Expected 0x%08x, got 0x%08x", backing_mem[32'h0000_0104 >> 2], rdata);
            fail_count++;
        end

        // Test 3: Write Hit and Dirty Mark (full word write)
        $display("[TEST 3] Write hit at 0x00000100");
        cpu_write(32'h0000_0100, 32'hA5A5_5A5A, 4'b1111);
        cpu_read(32'h0000_0100, rdata);
        if (rdata == 32'hA5A5_5A5A) begin
            $display("[PASS] Test 3: Write hit and immediate readback verified: 0x%08x", rdata);
            pass_count++;
        end else begin
            $display("[FAIL] Test 3: Expected 0x%08x, got 0x%08x", 32'hA5A5_5A5A, rdata);
            fail_count++;
        end

        // Test 4: Partial Byte Write (Byte Strobes)
        $display("[TEST 4] Partial byte write (strb=4'b0010) at 0x00000100");
        cpu_write(32'h0000_0100, 32'h0000_BB00, 4'b0010);
        cpu_read(32'h0000_0100, rdata);
        if (rdata == 32'hA5A5_BB5A) begin
            $display("[PASS] Test 4: Partial byte write preserved unmodified bytes: 0x%08x", rdata);
            pass_count++;
        end else begin
            $display("[FAIL] Test 4: Expected 0xA5A5BB5A, got 0x%08x", rdata);
            fail_count++;
        end

        // Test 5: Conflict Miss, Eviction of Dirty Line, and Refill
        // Address 0x0000_0500 maps to Set 16 ((0x500 >> 4) & 63 = 16), different tag!
        $display("[TEST 5] Conflict miss at 0x00000500 (Set 16 collision with dirty line)");
        cpu_write(32'h0000_0500, 32'hDEAD_BEEF, 4'b1111);
        cpu_read(32'h0000_0500, rdata);
        if (rdata == 32'hDEAD_BEEF) begin
            $display("[PASS] Test 5: Conflict write hit and readback verified: 0x%08x", rdata);
            pass_count++;
        end else begin
            $display("[FAIL] Test 5: Expected 0xDEADBEEF, got 0x%08x", rdata);
            fail_count++;
        end

        // Verify that evicted dirty line from 0x00000100 was committed to backing store!
        if (backing_mem[32'h0000_0100 >> 2] == 32'hA5A5_BB5A) begin
            $display("[PASS] Test 5b: Eviction properly wrote dirty line back to backing memory!");
            pass_count++;
        end else begin
            $display("[FAIL] Test 5b: Backing memory held 0x%08x instead of evicted 0xA5A5BB5A", backing_mem[32'h0000_0100 >> 2]);
            fail_count++;
        end

        // Test 6: Reload previously evicted line
        $display("[TEST 6] Reload previously evicted address 0x00000100");
        cpu_read(32'h0000_0100, rdata);
        if (rdata == 32'hA5A5_BB5A) begin
            $display("[PASS] Test 6: Reloaded evicted line contains written data: 0x%08x", rdata);
            pass_count++;
        end else begin
            $display("[FAIL] Test 6: Expected 0xA5A5BB5A, got 0x%08x", rdata);
            fail_count++;
        end

        $display("====================================================");
        $display("L1 CACHE REGRESSION: Total=%0d, Passed=%0d, Failed=%0d", pass_count + fail_count, pass_count, fail_count);
        $display("====================================================");

        if (fail_count > 0) begin
            $fatal(1, "[FAIL] L1 cache regression failed with %0d errors!", fail_count);
        end else begin
            $display("[SUCCESS] All L1 cache operations passed completely!");
            $finish;
        end
    end

endmodule
