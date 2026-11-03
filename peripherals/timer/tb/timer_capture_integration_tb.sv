`timescale 1ns/1ps

module timer_capture_integration_tb;
    initial begin #500000; $fatal(1, "Test timeout"); end

    logic pclk, presetn;

    initial begin
        pclk = 0;
        forever #40 pclk = ~pclk; // 12.5 MHz
    end

    initial begin
        presetn = 0;
        #250 presetn = 1;
    end

    apb_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) apb_req (.pclk(pclk), .presetn(presetn));

    logic capture_i;
    logic irq_o;

    timer_apb_wrapper #(
        .BASE_ADDR(32'h8000_2000)
    ) u_timer_wrapper (
        .apb(apb_req.completer),
        .capture_i(capture_i),
        .irq_o(irq_o)
    );

    task apb_write(input logic [31:0] addr, input logic [31:0] data, input logic [3:0] strb);
        @(posedge pclk);
        apb_req.paddr <= addr;
        apb_req.pwrite <= 1'b1;
        apb_req.psel <= 1'b1;
        apb_req.penable <= 1'b0;
        apb_req.pwdata <= data;
        apb_req.pstrb <= strb;
        @(posedge pclk);
        apb_req.penable <= 1'b1;
        @(posedge pclk);
        while (!apb_req.pready) @(posedge pclk);
        apb_req.psel <= 1'b0;
        apb_req.penable <= 1'b0;
    endtask

    task apb_read(input logic [31:0] addr, output logic [31:0] data);
        @(posedge pclk);
        apb_req.paddr <= addr;
        apb_req.pwrite <= 1'b0;
        apb_req.psel <= 1'b1;
        apb_req.penable <= 1'b0;
        apb_req.pstrb <= 4'h0;
        @(posedge pclk);
        apb_req.penable <= 1'b1;
        @(posedge pclk);
        while (!apb_req.pready) @(posedge pclk);
        data = apb_req.prdata;
        apb_req.psel <= 1'b0;
        apb_req.penable <= 1'b0;
    endtask

    logic [31:0] rdata;
    
    // Asynchronous capture driver
    task drive_capture_async(input logic val, input real delay_ns);
        #(delay_ns);
        capture_i = val;
    endtask

    initial begin
        capture_i = 1; // Held input before reset
        $dumpfile("capture_tb.vcd");
        $dumpvars(0, timer_capture_integration_tb);
        fork
            begin
                #50000;
                $error("TIMEOUT: Simulation ran too long!");
                $finish;
            end
            begin
                // Test body

        
        apb_req.paddr = 0;
        apb_req.pwrite = 0;
        apb_req.psel = 0;
        apb_req.penable = 0;
        apb_req.pwdata = 0;
        apb_req.pstrb = 0;
        apb_req.pprot = 0;

        wait(presetn);
        #100;

        // 1. Configure for Free-running mode, EN=1, CAP_EN=1, CAP_EDGE=00 (Rising)
        // Set count to known value
        apb_write(32'h8000_2004, 32'h0000_0100, 4'hF);
        
        // Wait some cycles to ensure baseline is acquired (timer RTL waits 3 cycles)
        repeat(5) @(posedge pclk);
        
        // Enable timer
        // bit 0: EN=1, bits 2:1: MODE=10 (Free-running), bit 3: CAP_EN=1, bits 5:4: CAP_EDGE=00
        apb_write(32'h8000_2000, 32'h0000_000D, 4'hF);
        
        // 2. No false edge when enabling with a held input (capture_i is 1)
        repeat(5) @(posedge pclk);
        apb_read(32'h8000_2014, rdata);
        if (rdata[2]) $error("False capture edge detected on startup");

        // 3. Drive asynchronous falling edge (should be ignored for rising mode)
        drive_capture_async(0, 15.3); // Async
        repeat(5) @(posedge pclk);
        apb_read(32'h8000_2014, rdata);
        if (rdata[2]) $error("False capture on falling edge (rising mode)");

        // 4. Drive asynchronous rising edge and check capture
        // Read current count
        begin
            logic [31:0] expected_cap;
            apb_read(32'h8000_2004, rdata);
            expected_cap = rdata + 3; // Account for 2-flop sync + edge detect latency
            
            drive_capture_async(1, 13.7);
            
            // Wait for IRQ_PENDING bit 2
            do begin
                apb_read(32'h8000_2014, rdata);
            end while (rdata[2] == 0);
            
            // Check CAPTURE_VALUE
            apb_read(32'h8000_2018, rdata);
            if (rdata !== expected_cap && rdata !== expected_cap+1 && rdata !== expected_cap-1)
                $error("Capture value mismatch. Expected ~%0h, Got %0h", expected_cap, rdata);
        end
        
        // 5. Check capture overrun
        // Don't clear pending, trigger another capture
        drive_capture_async(0, 20.0);
        repeat(3) @(posedge pclk);
        drive_capture_async(1, 20.0);
        
        repeat(5) @(posedge pclk);
        apb_read(32'h8000_2014, rdata);
        if (!rdata[3]) $error("Capture overrun not detected");

        // Clear pending (both capture and overrun)
        apb_write(32'h8000_2014, 32'h0000_000C, 4'hF);

        // Disable timer before changing mode (keep mode bits same, just EN=0)
        apb_write(32'h8000_2000, 32'h0000_000C, 4'hF);

        // 6. Test Falling edge mode
        // CAP_EDGE=01 (Falling), EN=1, CAP_EN=1
        apb_write(32'h8000_2000, 32'h0000_001D, 4'hF);
        
        drive_capture_async(0, 22.1);
        do begin
            apb_read(32'h8000_2014, rdata);
        end while (rdata[2] == 0);
        
        apb_write(32'h8000_2014, 32'h0000_0004, 4'hF); // clear

        // Disable timer before changing mode (keep mode bits same, just EN=0)
        apb_write(32'h8000_2000, 32'h0000_001C, 4'hF);

        // 7. Test Either edge mode
        // CAP_EDGE=10 (Either), EN=1, CAP_EN=1
        apb_write(32'h8000_2000, 32'h0000_002D, 4'hF);
        
        drive_capture_async(1, 17.5);
        do begin
            apb_read(32'h8000_2014, rdata);
        end while (rdata[2] == 0);
        apb_write(32'h8000_2014, 32'h0000_0004, 4'hF); // clear
        
        drive_capture_async(0, 11.2);
        do begin
            apb_read(32'h8000_2014, rdata);
        end while (rdata[2] == 0);
        
        $display("Capture Integration tests completed.");
        $finish;
            end
        join_any
        $finish;
    end

endmodule
