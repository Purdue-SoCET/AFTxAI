`timescale 1ns/1ps

module timer_ahb_integration_tb;
    initial begin #500000; $fatal(1, "Test timeout"); end

    logic hclk, pclk;
    logic hresetn, presetn;

    // Clock generation
    initial begin
        hclk = 0;
        forever #5 hclk = ~hclk; // 100 MHz
    end
    initial begin
        pclk = 0;
        forever #40 pclk = ~pclk; // 12.5 MHz
    end

    // Reset generation
    initial begin
        hresetn = 0;
        presetn = 0;
        #100 hresetn = 1;
        #100 presetn = 1;
    end

    // AHB Interface
    ahb_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) ahb (.HCLK(hclk), .HRESETn(hresetn));

    // APB Interface from Bridge
    apb_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) apb_req (.pclk(pclk), .presetn(presetn));

    // APB Completer interfaces
    apb_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) apb_comp[1] (.pclk(pclk), .presetn(presetn));

    // AHB to APB Bridge
    ahb2apb #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .BASE_ADDR(32'h8000_0000),
        .FIFO_DEPTH(16),
        .NWORDS(4096) // Covers up to 0x8000_3FFF
    ) u_bridge (
        .ahbif(ahb.subordinate),
        .apbif(apb_req.requester)
    );

    // APB Interconnect
    // Maps 0x0000_2000 (relative to bridge base)
    apb_interconnect #(
        .NCOMPLETERS(1),
        .COMPLETER_ADDR_BITS(12),
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .APB_MAP('{32'h0000_2000})
    ) u_interconnect (
        .requester(apb_req.completer),
        .completers(apb_comp)
    );

    // Timer Wrapper
    logic capture_i;
    logic irq_o;
    timer_apb_wrapper #(
        .BASE_ADDR(32'h0000_2000)
    ) u_timer_wrapper (
        .pclk(pclk),
        .presetn(presetn),
        .apb(apb_comp[0].completer),
        .capture_i(capture_i),
        .irq_o(irq_o)
    );

    // AHB Master Tasks
    task ahb_write(input logic [31:0] addr, input logic [31:0] data, input logic [3:0] strb, output logic err);
        @(posedge hclk);
        ahb.HSEL <= 1'b1;
        ahb.HADDR <= addr;
        ahb.HTRANS <= 2'b10; // NONSEQ
        ahb.HWRITE <= 1'b1;
        ahb.HSIZE <= 3'b010; // Word
        ahb.HWSTRB <= strb;
        @(posedge hclk);
        ahb.HSEL <= 1'b0;
        ahb.HTRANS <= 2'b00; // IDLE
        ahb.HWDATA <= data;
        while (1) begin
            @(posedge hclk);
            if (ahb.HREADYOUT) break;
        end
        err = ahb.HRESP;
    endtask

    task ahb_read(input logic [31:0] addr, output logic [31:0] data, output logic err);
        @(posedge hclk);
        ahb.HSEL <= 1'b1;
        ahb.HADDR <= addr;
        ahb.HTRANS <= 2'b10; // NONSEQ
        ahb.HWRITE <= 1'b0;
        ahb.HSIZE <= 3'b010; // Word
        ahb.HWSTRB <= 4'h0;
        @(posedge hclk);
        ahb.HSEL <= 1'b0;
        ahb.HTRANS <= 2'b00; // IDLE
        while (1) begin
            @(posedge hclk);
            if (ahb.HREADYOUT) break;
        end
        data = ahb.HRDATA;
        err = ahb.HRESP;
    endtask

    logic [31:0] rdata;
    logic err;

    initial begin
        $dumpfile("waves.vcd");
        $dumpvars(0, timer_ahb_integration_tb);
        capture_i = 0;
        ahb.HSEL = 0;
        ahb.HADDR = 0;
        ahb.HTRANS = 0;
        ahb.HWRITE = 0;
        ahb.HSIZE = 0;
        ahb.HWSTRB = 0;
        ahb.HWDATA = 0;
        ahb.HREADY = 1; // Master is always ready

        wait(hresetn && presetn);
        #100;

        // 1. Write Timer Control
        ahb_write(32'h8000_2008, 32'h12345678, 4'b1111, err);
        if (err) $error("AHB write failed");
        
        // 2. Read Timer Control
        ahb_read(32'h8000_2008, rdata, err);
        $display("Read back: %h, err: %b", rdata, err);
        if (rdata !== 32'h12345678 || err) $error("AHB read failed or mismatch");

        // 3. Error propagation (out of range APB access)
        ahb_read(32'h8000_2018, rdata, err); // Read RO register (OK)
        if (err) $error("Valid read returned error");

        ahb_write(32'h8000_2018, 32'hFFFFFFFF, 4'b1111, err); // Write RO register
        if (!err) $error("RO write did not propagate AHB error");

        // 4. Back-to-back accesses
        ahb_write(32'h8000_2004, 32'h00000010, 4'b1111, err);
        ahb_write(32'h8000_2008, 32'h00000020, 4'b1111, err);
        ahb_read(32'h8000_2004, rdata, err);
        $display("B2B read back: %h, err: %b", rdata, err);
        if (rdata !== 32'h00000010) $error("B2B write/read failed");

        // 5. Unmapped bridge address
        ahb_read(32'h8000_4000, rdata, err); // Outside NWORDS window
        if (!err) $error("Unmapped bridge read did not error");

        $display("AHB Integration tests completed.");
        $finish;
    end

endmodule
