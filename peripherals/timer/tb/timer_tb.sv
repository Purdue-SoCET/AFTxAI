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

    task do_write(input [12:0] addr, input [31:0] data, input [3:0] strb);
        @(posedge pclk);
        paddr <= addr;
        psel <= 1;
        penable <= 0;
        pwrite <= 1;
        pwdata <= data;
        pstrb <= strb;
        @(posedge pclk);
        penable <= 1;
        @(posedge pclk);
        psel <= 0;
        penable <= 0;
    endtask

    task do_read(input [12:0] addr, output [31:0] data, output err);
        @(posedge pclk);
        paddr <= addr;
        psel <= 1;
        penable <= 0;
        pwrite <= 0;
        pstrb <= 0;
        @(posedge pclk);
        penable <= 1;
        @(posedge pclk);
        data = prdata;
        err = pslverr;
        psel <= 0;
        penable <= 0;
    endtask

    logic [31:0] rdata;
    logic err;

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
        presetn = 1;
        repeat (5) @(posedge pclk);

        // T01: Read registers after reset
        do_read(13'h0000, rdata, err);
        assert(rdata == 32'h0 && err == 0) else $fatal(1, "T01: CONTROL reset error");
        do_read(13'h0008, rdata, err);
        assert(rdata == 32'hFFFF_FFFF && err == 0) else $fatal(1, "T01: PERIOD reset error");

        // T03: Write and read mapped registers
        do_write(13'h0008, 32'h12345678, 4'hF);
        do_read(13'h0008, rdata, err);
        assert(rdata == 32'h12345678 && err == 0) else $fatal(1, "T03: PERIOD write/read error");

        // T04: PSTRB masks
        do_write(13'h0008, 32'hAAAAAAAA, 4'h3); // Write lower half
        do_read(13'h0008, rdata, err);
        assert(rdata == 32'h1234AAAA && err == 0) else $fatal(1, "T04: PSTRB masking error");

        // T05: Invalid addresses
        do_read(13'h0020, rdata, err);
        assert(err == 1) else $fatal(1, "T05: Invalid address did not error");

        // Run basic counting
        do_write(13'h0008, 32'h00000002, 4'hF); // PERIOD=2
        do_write(13'h000C, 32'h00000000, 4'hF); // PRESCALE=0
        do_write(13'h0000, 32'h00000001, 4'hF); // EN=1, MODE=00 (periodic)

        repeat (6) @(posedge pclk);
        do_read(13'h0004, rdata, err);
        // It should have matched and wrapped
        assert(err == 0) else $fatal(1, "Read error during running");
        
        // Stop timer
        do_write(13'h0000, 32'h00000000, 4'hF);
        
        $display("Directed Tests Passed");
        $finish;
    end
endmodule
