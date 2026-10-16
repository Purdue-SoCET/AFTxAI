`timescale 1ns/1ps

module timer_tb;
    logic pclk;
    logic presetn;
    logic [12:0] paddr;
    logic psel;
    logic penable;
    logic pwrite;
    logic [31:0] pwdata;
    logic [3:0] pstrb;
    logic [2:0] pprot;
    logic [31:0] prdata;
    logic pready;
    logic pslverr;
    logic capture_i;
    logic irq_o;

    timer_apb dut (.*);

    initial begin
        pclk = 0;
        forever #40 pclk = ~pclk; // 12.5 MHz = 80ns period
    end

    task do_setup_only(input [12:0] addr, input [31:0] data, input [3:0] strb);
        @(posedge pclk);
        paddr <= addr;
        psel <= 1;
        penable <= 0;
        pwrite <= 1;
        pwdata <= data;
        pstrb <= strb;
        @(posedge pclk);
        psel <= 0; // Abort before access
    endtask

    task do_write(input [12:0] addr, input [31:0] data, input [3:0] strb, output err, input [2:0] prot=0);
        @(posedge pclk);
        paddr <= addr;
        psel <= 1;
        penable <= 0;
        pwrite <= 1;
        pwdata <= data;
        pstrb <= strb;
        pprot <= prot;
        @(posedge pclk);
        penable <= 1;
        @(posedge pclk);
        err = pslverr;
        psel <= 0;
        penable <= 0;
    endtask

    task do_write_no_err(input [12:0] addr, input [31:0] data, input [3:0] strb, input [2:0] prot=0);
        logic dummy_err;
        do_write(addr, data, strb, dummy_err, prot);
    endtask
    
    task do_read_raw(input [12:0] addr, input [3:0] strb, output [31:0] data, output err, input [2:0] prot=0);
        @(posedge pclk);
        paddr <= addr;
        psel <= 1;
        penable <= 0;
        pwrite <= 0;
        pstrb <= strb;
        pprot <= prot;
        @(posedge pclk);
        penable <= 1;
        @(posedge pclk);
        data = prdata;
        err = pslverr;
        psel <= 0;
        penable <= 0;
    endtask

    task do_read(input [12:0] addr, output [31:0] data, output err, input [2:0] prot=0);
        do_read_raw(addr, 4'h0, data, err, prot);
    endtask

    logic [31:0] rdata;
    logic err;
    logic [31:0] expected;
    logic [31:0] expected_cap;

    initial begin
        presetn = 0;
        paddr = 0;
        psel = 0;
        penable = 0;
        pwrite = 0;
        pwdata = 0;
        pstrb = 0;
        pprot = 0;
        capture_i = 0;

        repeat (5) @(posedge pclk);
        // T01: Assert reset between edges
        #10 presetn = 1;
        repeat (5) @(posedge pclk);

        // T01 Check resets
        do_read(13'h0000, rdata, err); assert(rdata == 0 && err == 0) else $fatal(1, "T01");
        do_read(13'h0008, rdata, err); assert(rdata == 32'hFFFF_FFFF && err == 0) else $fatal(1, "T01");

        // T02: SETUP only
        do_setup_only(13'h0008, 32'h12345678, 4'hF);
        do_read(13'h0008, rdata, err); assert(rdata == 32'hFFFF_FFFF && err == 0) else $fatal(1, "T02");

        // T03: Valid writes
        do_write_no_err(13'h0008, 32'h12345678, 4'hF);
        do_read(13'h0008, rdata, err); assert(rdata == 32'h12345678 && err == 0) else $fatal(1, "T03");

        // T04: PSTRB masks
        for (int addr=0; addr<=13'h10; addr+=4) begin // CONTROL, COUNT, PERIOD, PRESCALE, IRQ_ENABLE
            do_write_no_err(addr, 32'h00000000, 4'hF); // Reset to 0
            for (int i=0; i<16; i++) begin
                do_write_no_err(addr, 32'hFFFFFFFF, i[3:0]);
                do_read(addr, rdata, err);
                assert(err == 0) else $fatal(1, "T04 err");
                expected = 0;
                if (i[0]) expected[7:0]   = 8'hFF;
                if (i[1]) expected[15:8]  = 8'hFF;
                if (i[2]) expected[23:16] = 8'hFF;
                if (i[3]) expected[31:24] = 8'hFF;
                
                // Mask expected based on writable bits
                if (addr == 13'h00) begin
                    expected = expected & 32'h0000_003F; // CONTROL has 6 bits
                    if (expected[2:1] == 2'b11 || expected[5:4] == 2'b11) expected = 0; // Illegal modes get rejected
                end
                if (addr == 13'h0C) expected = expected & 32'h0000_FFFF; // PRESCALE has 16 bits
                if (addr == 13'h10) expected = expected & 32'h0000_000F; // IRQ_ENABLE has 4 bits

                assert(rdata == expected) else begin
                    $display("T04 mismatch at addr=%h with PSTRB=%b. Expected %h, got %h", addr, i[3:0], expected, rdata);
                    $fatal(1, "T04 data mismatch");
                end
                do_write_no_err(addr, 32'h00000000, 4'hF); 
            end
        end

        // zero-strobe no-op while running
        do_write_no_err(13'h0008, 32'h2, 4'hF);
        do_write_no_err(13'h0000, 32'h1, 4'hF);
        do_write(13'h0008, 32'hFFFFFFFF, 4'h0, err); // Should be no-op, not error, and not write
        assert(err == 0) else $fatal(1, "T04 zero-strobe err while running");
        do_write_no_err(13'h0000, 32'h0, 4'hF);

        // T05: Invalid addresses
        do_read(13'h0020, rdata, err); assert(err == 1) else $fatal(1, "T05");
        do_read(13'h0100, rdata, err); assert(err == 1) else $fatal(1, "T05");
        do_read(13'h1000, rdata, err); assert(err == 1) else $fatal(1, "T05");
        do_read(13'h1FFC, rdata, err); assert(err == 1) else $fatal(1, "T05");

        // T06: Misaligned, RO write, nonzero PSTRB read
        do_read(13'h0001, rdata, err); assert(err == 1) else $fatal(1, "T06 misalign");
        do_write(13'h0018, 32'hFFFFFFFF, 4'hF, err); assert(err == 1) else $fatal(1, "T06 RO write");
        do_read_raw(13'h0000, 4'hF, rdata, err); assert(err == 1 && rdata == 0) else $fatal(1, "T06 PSTRB!=0 read");

        // T07: PPROT
        for (int i=0; i<8; i++) begin
            do_read(13'h001C, rdata, err, i[2:0]); 
            assert(err == 0 && rdata == 32'h544D_0101) else $fatal(1, "T07");
        end

        // T08: Stop to start tick suppression (EN=1 write doesn't tick)
        // Reset timer state
        do_write_no_err(13'h0000, 32'h0, 4'hF);
        do_write_no_err(13'h0004, 32'h0, 4'hF); // COUNT=0
        do_write_no_err(13'h000C, 32'h0, 4'hF); // PRESCALE=0
        do_write_no_err(13'h0008, 32'h10, 4'hF); // PERIOD=16
        
        // Write EN=1
        @(posedge pclk); paddr <= 13'h0000; psel <= 1; penable <= 0; pwrite <= 1; pwdata <= 32'h1; pstrb <= 4'hF;
        @(posedge pclk); penable <= 1;
        @(posedge pclk); // This is the completion edge
        #1;
        psel <= 0; penable <= 0;
        assert(dut.count_reg == 0) else $fatal(1, "T08 tick on enable");
        @(posedge pclk); 
        #1;
        // First tick happens here, count becomes 1
        assert(dut.count_reg == 1) else $fatal(1, "T08 no tick after enable");
        do_write_no_err(13'h0000, 32'h0, 4'hF); // Stop

        // T09: PRESCALE=0, PERIOD=2 periodic (match at 3rd tick)
        do_write_no_err(13'h0000, 32'h0, 4'hF);
        do_write_no_err(13'h0004, 32'h0, 4'hF); // COUNT=0
        do_write_no_err(13'h0008, 32'h2, 4'hF); // PERIOD=2
        do_write_no_err(13'h0014, 32'hF, 4'hF); // W1C
        
        @(posedge pclk); paddr <= 13'h0000; psel <= 1; penable <= 0; pwrite <= 1; pwdata <= 32'h1; pstrb <= 4'hF;
        @(posedge pclk); penable <= 1;
        @(posedge pclk); #1; psel <= 0; penable <= 0; // completion edge (tick 0)
        @(posedge pclk); #1; // tick 1, count=1
        assert(dut.count_reg == 1) else $fatal(1, "T09 tick 1");
        @(posedge pclk); #1; // tick 2, count=2
        assert(dut.count_reg == 2) else $fatal(1, "T09 tick 2");
        @(posedge pclk); #1; // tick 3, count=0, match=1
        assert(dut.count_reg == 0 && dut.irq_pending_reg[0] == 1) else $fatal(1, "T09 match");
        do_write_no_err(13'h0000, 32'h0, 4'hF);

        // T10: PRESCALE=2, PERIOD=2
        do_write_no_err(13'h0000, 32'h0, 4'hF);
        do_write_no_err(13'h0014, 32'hF, 4'hF);
        do_write_no_err(13'h0004, 32'h0, 4'hF);
        do_write_no_err(13'h000C, 32'h2, 4'hF);
        
        @(posedge pclk); paddr <= 13'h0000; psel <= 1; penable <= 0; pwrite <= 1; pwdata <= 32'h1; pstrb <= 4'hF;
        @(posedge pclk); penable <= 1;
        @(posedge pclk); #1; psel <= 0; penable <= 0; // cycle 0 (completion)
        @(posedge pclk); #1; // cycle 1
        @(posedge pclk); #1; // cycle 2
        @(posedge pclk); #1; // cycle 3 (tick 1, count=1)
        assert(dut.count_reg == 1) else $fatal(1, "T10 count 1");
        @(posedge pclk); #1; // cycle 4
        @(posedge pclk); #1; // cycle 5
        @(posedge pclk); #1; // cycle 6 (tick 2, count=2)
        assert(dut.count_reg == 2) else $fatal(1, "T10 count 2");
        @(posedge pclk); #1; // cycle 7
        @(posedge pclk); #1; // cycle 8
        assert(dut.irq_pending_reg[0] == 0) else $fatal(1, "T10 match early");
        @(posedge pclk); #1; // cycle 9 (tick 3, match)
        assert(dut.irq_pending_reg[0] == 1 && dut.count_reg == 0) else $fatal(1, "T10 match");
        do_write_no_err(13'h0000, 32'h0, 4'hF);

        // T11: PERIOD=0 periodic
        do_write_no_err(13'h0000, 32'h0, 4'hF);
        do_write_no_err(13'h0014, 32'hF, 4'hF);
        do_write_no_err(13'h0004, 32'h0, 4'hF);
        do_write_no_err(13'h0008, 32'h0, 4'hF);
        do_write_no_err(13'h000C, 32'h0, 4'hF);
        do_write_no_err(13'h0000, 32'h1, 4'hF);
        repeat(2) @(posedge pclk);
        do_read(13'h0004, rdata, err); assert(rdata == 0) else $fatal(1, "T11");
        do_read(13'h0014, rdata, err); assert(rdata[0] == 1) else $fatal(1, "T11");
        do_write_no_err(13'h0000, 32'h0, 4'hF);
        
        // T12: One-shot expiration
        do_write_no_err(13'h0014, 32'hF, 4'hF);
        do_write_no_err(13'h0004, 32'h0, 4'hF);
        do_write_no_err(13'h0008, 32'h2, 4'hF);
        do_write_no_err(13'h000C, 32'h0, 4'hF);
        do_write_no_err(13'h0000, 32'h3, 4'hF); // EN=1, MODE=01 (One-shot)
        repeat(5) @(posedge pclk);
        do_read(13'h0000, rdata, err); assert(rdata[0] == 0) else $fatal(1, "T12 auto-clear");
        do_read(13'h0004, rdata, err); assert(rdata == 2) else $fatal(1, "T12 count");
        
        // T13: One-shot re-enable from expiry
        do_write_no_err(13'h0014, 32'hF, 4'hF); // W1C
        do_write_no_err(13'h0000, 32'h3, 4'hF); // EN=1 again
        repeat(3) @(posedge pclk);
        do_read(13'h0004, rdata, err); assert(rdata == 2) else $fatal(1, "T13 count");
        do_read(13'h0014, rdata, err); assert(rdata[0] == 1) else $fatal(1, "T13 match");
        do_write_no_err(13'h0000, 32'h0, 4'hF);

        // T14, T15: Free run wrap and match at FFFFFFFF
        do_write_no_err(13'h0014, 32'hF, 4'hF);
        do_write_no_err(13'h0004, 32'hFFFF_FFFE, 4'hF);
        do_write_no_err(13'h0008, 32'hFFFF_FFFF, 4'hF);
        do_write_no_err(13'h000C, 32'h0, 4'hF);
        do_write_no_err(13'h0000, 32'h5, 4'hF); // EN=1, MODE=10 (Free-run)
        repeat(4) @(posedge pclk);
        do_read(13'h0014, rdata, err); assert(rdata[0] == 1 && rdata[1] == 1) else $fatal(1, "T15 match&wrap");
        do_read(13'h0004, rdata, err); assert(rdata < 10) else $fatal(1, "T14 count wrap");
        do_write_no_err(13'h0000, 32'h4, 4'hF);

        // T16: COUNT>PERIOD while disabled allowed
        do_write_no_err(13'h0004, 32'h10, 4'hF);
        do_write_no_err(13'h0008, 32'h05, 4'hF);
        do_write(13'h0000, 32'h1, 4'hF, err); // Try to enable periodic
        assert(err == 1) else $fatal(1, "T16 atomic error");

        // T17, T18: Writes to config while running
        do_write_no_err(13'h0004, 32'h0, 4'hF); // Valid count
        do_write_no_err(13'h0000, 32'h1, 4'hF); // EN=1
        do_write(13'h0008, 32'h55, 4'hF, err); // PERIOD
        assert(err == 1) else $fatal(1, "T17");
        do_write(13'h0000, 32'h3, 4'hF, err); // Change to One-shot
        assert(err == 1) else $fatal(1, "T18");
        do_write_no_err(13'h0000, 32'h0, 4'hF); // Stop

        // T19: IRQ output and mask
        do_write_no_err(13'h0000, 32'h0, 4'hF); // Make sure we are stopped first
        do_write_no_err(13'h0014, 32'hF, 4'hF);
        do_write_no_err(13'h0010, 32'h0, 4'hF); // Mask all
        do_write_no_err(13'h0004, 32'h0, 4'hF);
        do_write_no_err(13'h0008, 32'h1, 4'hF);
        do_write_no_err(13'h0000, 32'h1, 4'hF);
        repeat(4) @(posedge pclk);
        assert(irq_o == 0) else $fatal(1, "T19 masked");
        do_write_no_err(13'h0000, 32'h0, 4'hF); // Stop the timer so we can check W1C reliably without new MATCHes
        do_write_no_err(13'h0010, 32'h1, 4'hF); // Unmask match
        @(posedge pclk); #1;
        $display("T19: count=%0d, period=%0d, pending=%b, enable=%b, irq_o=%b", dut.count_reg, dut.period_reg, dut.irq_pending_reg, dut.irq_enable_reg, irq_o);
        assert(irq_o == 1) else $fatal(1, "T19 unmasked");

        // T20: W1C clears only strobed
        do_write_no_err(13'h0014, 32'h1, 4'h1); // W1C Match
        @(posedge pclk); #1;
        assert(irq_o == 0) else $fatal(1, "T20 W1C");
        do_write_no_err(13'h0000, 32'h0, 4'hF);

        // T21: MATCH and W1C collision on same edge
        do_write_no_err(13'h0004, 32'h0, 4'hF);
        do_write_no_err(13'h0008, 32'h2, 4'hF); // PERIOD=2
        do_write_no_err(13'h0014, 32'hF, 4'hF); // clear pending
        do_write_no_err(13'h0000, 32'h3, 4'hF); // Start, One-shot (MODE=01)
        
        @(posedge pclk); // Cycle 2
        paddr <= 13'h0014; psel <= 1; penable <= 0; pwrite <= 1; pwdata <= 32'h1; pstrb <= 4'hF;
        @(posedge pclk); // Cycle 3
        penable <= 1;
        @(posedge pclk); #1; // Cycle 4 (MATCH and W1C collide)
        psel <= 0; penable <= 0;
        do_read(13'h0014, rdata, err); assert(rdata[0] == 1) else $fatal(1, "T21 collision HW SET priority");
        do_write_no_err(13'h0000, 32'h0, 4'hF);

        // T22-T25: Capture
        #10 presetn = 0; #100 presetn = 1; // Reset to get capture baseline
        repeat(5) @(posedge pclk);
        do_write_no_err(13'h0008, 32'hFFFF_FFFF, 4'hF);
        
        // T22/T23: Rising edge capture
        do_write_no_err(13'h0000, 32'h9, 4'hF); // EN=1, CAP_EN=1, EDGE=00 (rising)
        repeat(2) @(posedge pclk);
        
        // Ensure falling edge is ignored
        capture_i = 0; // Falling edge
        repeat(4) @(posedge pclk);
        do_read(13'h0014, rdata, err); assert(rdata[2] == 0) else $fatal(1, "T22 falling edge wrongly captured");
        
        // Now rising edge
        @(posedge pclk);
        #1;
        // The synchronizer delays the edge by 2 cycles (sync, sync_d1). 
        // The capture occurs on the cycle where cap_event is high, capturing count_reg at THAT cycle.
        // If we assert capture_i=1 now, it propagates to capture_sync next cycle, 
        // and capture_sync_d1 the cycle after.
        // cap_event goes high the cycle after that.
        // This means it captures the count_reg exactly 2 cycles later.
        expected_cap = dut.count_reg + 2; 
        capture_i = 1; // Rising edge
        
        repeat(4) @(posedge pclk);
        do_read(13'h0014, rdata, err); assert(rdata[2] == 1) else $fatal(1, "T22 cap pend");
        do_read(13'h0018, rdata, err); 
        assert(rdata == expected_cap) else begin
            $display("T23 RISING mismatch: expected %d, got %d", expected_cap, rdata);
            $fatal(1, "T23 exact cap val mismatch");
        end
        do_write_no_err(13'h0014, 32'h4, 4'hF); // W1C
        
        do_write_no_err(13'h0000, 32'h8, 4'hF); // Stop first
        do_write_no_err(13'h0000, 32'h19, 4'hF); // EN=1, CAP_EN=1, EDGE=01 (falling)
        repeat(2) @(posedge pclk);
        capture_i = 1; // already 1
        @(posedge pclk);
        #1;
        expected_cap = dut.count_reg + 2;
        capture_i = 0; // Falling edge
        
        repeat(4) @(posedge pclk);
        do_read(13'h0014, rdata, err); assert(rdata[2] == 1) else $fatal(1, "T22 falling cap pend");
        do_read(13'h0018, rdata, err); 
        assert(rdata == expected_cap) else begin
            $display("T23 FALLING mismatch: expected %d, got %d", expected_cap, rdata);
            $fatal(1, "T23 falling exact cap val mismatch");
        end
        do_write_no_err(13'h0014, 32'h4, 4'hF); // W1C
        
        // T22/T23: Either edge capture
        do_write_no_err(13'h0000, 32'h18, 4'hF); // Stop first
        do_write_no_err(13'h0000, 32'h29, 4'hF); // EN=1, CAP_EN=1, EDGE=10 (either)
        repeat(2) @(posedge pclk);
        @(posedge pclk);
        #1;
        expected_cap = dut.count_reg + 2;
        capture_i = 1; // Rising edge
        repeat(4) @(posedge pclk);
        do_read(13'h0014, rdata, err); assert(rdata[2] == 1) else $fatal(1, "T22 either(R) cap pend");
        do_read(13'h0018, rdata, err); 
        assert(rdata == expected_cap) else begin
            $display("T23 EITHER mismatch: expected %d, got %d", expected_cap, rdata);
            $fatal(1, "T23 either(R) exact cap val mismatch");
        end
        do_write_no_err(13'h0014, 32'h4, 4'hF); // W1C

        
        capture_i = 0; repeat(4) @(posedge pclk);
        capture_i = 1; repeat(4) @(posedge pclk); // Second capture
        do_read(13'h0014, rdata, err); assert(rdata[3] == 1) else $fatal(1, "T24 overrun");
        
        do_write_no_err(13'h0014, 32'h4, 4'hF); // W1C Capture only
        @(posedge pclk);
        do_read(13'h0014, rdata, err); assert(rdata[2] == 0 && rdata[3] == 1) else $fatal(1, "T24 w1c independent");

        // T26: Async reset while running
        #15 presetn = 0;
        #15 presetn = 1;
        do_read(13'h0000, rdata, err); assert(rdata == 0) else $fatal(1, "T26");

        // T27: Back-to-back APB transfers
        // Issue two writes back to back
        @(posedge pclk); paddr <= 13'h04; psel <= 1; penable <= 0; pwrite <= 1; pwdata <= 32'h10; pstrb <= 4'hF;
        @(posedge pclk); penable <= 1;
        @(posedge pclk); paddr <= 13'h08; psel <= 1; penable <= 0; pwrite <= 1; pwdata <= 32'h20; pstrb <= 4'hF;
        @(posedge pclk); penable <= 1;
        @(posedge pclk); psel <= 0; penable <= 0;
        do_read(13'h04, rdata, err); assert(rdata == 32'h10) else $fatal(1, "T27");
        do_read(13'h08, rdata, err); assert(rdata == 32'h20) else $fatal(1, "T27");
        
        // T28: Illegal CONTROL encoding
        do_write(13'h0000, 32'h6, 4'hF, err); // MODE=11
        assert(err == 1) else $fatal(1, "T28 mode 11");

        $display("All Directed Tests Passed");
        $finish;
    end
endmodule
