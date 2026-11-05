`timescale 1ns/1ps

module tb_uart_top;

    // --- Parameters ---
    parameter int CLK_FREQ = 50_000_000;
    parameter int DEFAULT_BAUD = 115200;
    parameter int CLK_PERIOD_NS = 20;
    
    // --- Signals ---
    logic clk = 0;
    logic rst_n = 0;
    int errors = 0;
    
    always #(CLK_PERIOD_NS/2) clk = ~clk;
    
    // --- Interfaces ---
    uart_if uif(
        .clk(clk),
        .rst_n(rst_n)
    );
    
    // --- DUT ---
    uart_top #(
        .CLOCK_FREQ_HZ(CLK_FREQ),
        .DEFAULT_BAUD(DEFAULT_BAUD)
    ) dut (
        .vif(uif.target)
    );
    
    // --- BFM Tasks ---
    task automatic apb_write(input logic [31:0] addr, input logic [31:0] data);
        @(posedge clk);
        uif.PSEL <= 1'b1;
        uif.PADDR <= addr;
        uif.PWRITE <= 1'b1;
        uif.PWDATA <= data;
        uif.PENABLE <= 1'b0;
        
        @(posedge clk);
        uif.PENABLE <= 1'b1;
        
        @(posedge clk);
        while (!uif.PREADY) @(posedge clk);
        uif.PSEL <= 1'b0;
        uif.PENABLE <= 1'b0;
    endtask

    task automatic apb_read(input logic [31:0] addr, output logic [31:0] data);
        @(posedge clk);
        uif.PSEL <= 1'b1;
        uif.PADDR <= addr;
        uif.PWRITE <= 1'b0;
        uif.PENABLE <= 1'b0;
        
        @(posedge clk);
        uif.PENABLE <= 1'b1;
        
        @(posedge clk);
        while (!uif.PREADY) @(posedge clk);
        data = uif.PRDATA;
        uif.PSEL <= 1'b0;
        uif.PENABLE <= 1'b0;
    endtask

    // Initial block
    initial begin
        clk = 0;
        rst_n = 0;
        uif.PSEL = 0;
        uif.PENABLE = 0;
        uif.PWRITE = 0;
        uif.PADDR = 0;
        uif.PWDATA = 0;
        uif.rx = 1;
        uif.cts_n = 0;

        #100;
        rst_n = 1;
        #100;

        // Try to read Line Control Register (Offset 0x0C)
        begin
            logic [31:0] rdata;
            apb_read(32'h0C, rdata);
            if (rdata !== 32'h03) begin
                $display("ERROR: Expected LCR default 0x03, got 0x%0x", rdata);
                errors++;
            end else begin
                $display("PASS: LCR read correctly.");
            end
        end
        
        // Write to TX FIFO (Offset 0x00)
        apb_write(32'h00, 32'h55);
        $display("Wrote 0x55 to TX FIFO");
        
        // Wait some time for TX to start
        #50000;
        
        if (errors == 0)
            $display("TEST PASSED");
        else
            $display("TEST FAILED with %0d errors", errors);
        
        $finish;
    end
endmodule
