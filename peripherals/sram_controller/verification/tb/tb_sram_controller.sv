`timescale 1ns/1ps

module tb_sram_controller();
    parameter int WAIT_CYCLES = 2;
    parameter int ADDR_WIDTH = 19;

    logic HCLK;
    logic nRST;

    bus_protocol_if #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32)
    ) bus();

    sram_if #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) sram();

    // DUT
    sram_controller #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .WAIT_CYCLES(WAIT_CYCLES)
    ) dut (
        .HCLK(HCLK),
        .nRST(nRST),
        .bus(bus.peripheral_vital),
        .sram(sram.controller)
    );

    // Clock generation
    initial begin
        HCLK = 0;
        forever #5 HCLK = ~HCLK;
    end

    // SRAM arrays
    logic [15:0] mem0 [0:1023];
    logic [15:0] mem1 [0:1023];

    // SRAM memory model (reads)
    logic [15:0] next_rdata;
    always_comb begin
        next_rdata = 16'hxxxx;
        if (sram.pad_oe) begin
            if (~sram.ce0_n && ~sram.oe0_n) next_rdata = mem0[sram.addr[9:0]];
            else if (~sram.ce1_n && ~sram.oe1_n) next_rdata = mem1[sram.addr[9:0]];
        end
    end

    // sram.rdata should be driven when pad_oe is 1
    assign sram.rdata = next_rdata;

    // SRAM memory model (writes)
    always @(posedge HCLK or negedge nRST) begin
        if (~nRST) begin
            for (int i=0; i<1024; i++) begin
                mem0[i] <= 16'h0000;
                mem1[i] <= 16'h0000;
            end
        end else begin
            if (~sram.ce0_n && ~sram.we0_n) begin
                if (~sram.ub0_n) mem0[sram.addr[9:0]][15:8] <= sram.wdata[15:8];
                if (~sram.lb0_n) mem0[sram.addr[9:0]][7:0] <= sram.wdata[7:0];
            end
            if (~sram.ce1_n && ~sram.we1_n) begin
                if (~sram.ub1_n) mem1[sram.addr[9:0]][15:8] <= sram.wdata[15:8];
                if (~sram.lb1_n) mem1[sram.addr[9:0]][7:0] <= sram.wdata[7:0];
            end
        end
    end

    int err_cnt = 0;

    task bus_write(input logic [31:0] addr, input logic [31:0] data, input logic [3:0] strobe);
        @(posedge HCLK);
        bus.wen = 1'b1;
        bus.ren = 1'b0;
        bus.addr = addr;
        bus.wdata = data;
        bus.strobe = strobe;
        // Wait for request_stall to drop
        do begin
            @(posedge HCLK);
        end while (bus.request_stall);
        bus.wen = 1'b0;
    endtask

    task bus_read(input logic [31:0] addr, output logic [31:0] data, input logic [3:0] strobe);
        @(posedge HCLK);
        bus.wen = 1'b0;
        bus.ren = 1'b1;
        bus.addr = addr;
        bus.strobe = strobe;
        do begin
            @(posedge HCLK);
        end while (bus.request_stall);
        data = bus.rdata;
        bus.ren = 1'b0;
    endtask

    logic [31:0] read_val;

    initial begin
        bus.wen = 0;
        bus.ren = 0;
        bus.addr = 0;
        bus.wdata = 0;
        bus.strobe = 0;

        nRST = 0;
        #20 nRST = 1;
        #10;
        $display("Testing full word write and read...");
        bus_write(32'h0002_0004, 32'hDEADBEEF, 4'b1111);
        
        bus_read(32'h0002_0004, read_val, 4'b1111);
        if (read_val !== 32'hDEADBEEF) begin
            $display("FAIL: Expected 32'hDEADBEEF, got %h", read_val);
            err_cnt++;
        end else begin
            $display("PASS: Full word write and read");
        end

        // T06: Skip Access 1
        $display("Testing skip Access 1 (upper halfword only)...");
        bus_write(32'h0002_0008, 32'hCAFE0000, 4'b1100);
        bus_read(32'h0002_0008, read_val, 4'b1100);
        if (read_val !== 32'hCAFE0000) begin
            $display("FAIL: Expected CAFE0000, got %h", read_val);
            err_cnt++;
        end else begin
            $display("PASS: Skip Access 1");
        end

        // T06: Skip Access 2
        $display("Testing skip Access 2 (lower halfword only)...");
        bus_write(32'h0002_000C, 32'h0000BABE, 4'b0011);
        bus_read(32'h0002_000C, read_val, 4'b0011);
        if (read_val !== 32'h0000BABE) begin
            $display("FAIL: Expected 0000BABE, got %h", read_val);
            err_cnt++;
        end else begin
            $display("PASS: Skip Access 2");
        end

        // T08: check error signal
        if (bus.error !== 1'b0) begin
            $display("FAIL: Error signal is asserted");
            err_cnt++;
        end

        #50;
        if (err_cnt == 0) begin
            $display("ALL TESTS PASSED");
        end else begin
            $display("FAILED with %0d errors", err_cnt);
            $fatal(1, "Testbench failed.");
        end
        $finish;
    end
endmodule
