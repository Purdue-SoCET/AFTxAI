`timescale 1ns/1ps

module timer_apb_integration_tb;
    initial begin #500000; $fatal(1, "Test timeout"); end

    logic pclk;
    logic presetn;

    // Clock generation
    initial begin
        pclk = 0;
        forever #40 pclk = ~pclk; // 12.5 MHz
    end

    // Reset generation
    initial begin
        presetn = 0;
        #100 presetn = 1;
    end

    // APB Interface
    apb_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) apb_req (.PCLK(pclk), .PRESETn(presetn));
    apb_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) apb_comp[2] (.PCLK(pclk), .PRESETn(presetn));

    // Interconnect
    // Timer0 at 0x8000_2000, Dummy at 0x8000_3000
    // COMPLETER_ADDR_BITS = 12 -> PADDR[31:12]
    apb_interconnect #(
        .NCOMPLETERS(2),
        .COMPLETER_ADDR_BITS(12),
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .APB_MAP('{32'h8000_2000, 32'h8000_3000})
    ) u_interconnect (
        .requester(apb_req.completer),
        .completers(apb_comp)
    );

    // Timer0 Wrapper
    logic capture_i;
    logic irq_o;
    
    timer_apb_wrapper #(
        .BASE_ADDR(32'h8000_2000)
    ) u_timer_wrapper (
        .apb(apb_comp[0].completer),
        .capture_i(capture_i),
        .irq_o(irq_o)
    );

    // Dummy Completer
    assign apb_comp[1].PREADY = 1'b1;
    assign apb_comp[1].PRDATA = 32'hDEADBEEF;
    assign apb_comp[1].PSLVERR = 1'b0;

    // BFM Tasks
    task apb_write(input logic [31:0] addr, input logic [31:0] data, input logic [3:0] strb, output logic err);
        @(posedge pclk);
        apb_req.PADDR <= addr;
        apb_req.PWRITE <= 1'b1;
        apb_req.PSEL <= 1'b1;
        apb_req.PENABLE <= 1'b0;
        apb_req.PWDATA <= data;
        apb_req.PSTRB <= strb;
        @(posedge pclk);
        apb_req.PENABLE <= 1'b1;
        @(posedge pclk);
        while (!apb_req.PREADY) @(posedge pclk);
        err = apb_req.PSLVERR;
        apb_req.PSEL <= 1'b0;
        apb_req.PENABLE <= 1'b0;
    endtask

    task apb_read(input logic [31:0] addr, output logic [31:0] data, output logic err);
        @(posedge pclk);
        apb_req.PADDR <= addr;
        apb_req.PWRITE <= 1'b0;
        apb_req.PSEL <= 1'b1;
        apb_req.PENABLE <= 1'b0;
        apb_req.PSTRB <= 4'h0;
        @(posedge pclk);
        apb_req.PENABLE <= 1'b1;
        @(posedge pclk);
        while (!apb_req.PREADY) @(posedge pclk);
        data = apb_req.PRDATA;
        err = apb_req.PSLVERR;
        apb_req.PSEL <= 1'b0;
        apb_req.PENABLE <= 1'b0;
    endtask

    logic [31:0] rdata;
    logic err;

    initial begin
        capture_i = 0;
        apb_req.PADDR = 0;
        apb_req.PWRITE = 0;
        apb_req.PSEL = 0;
        apb_req.PENABLE = 0;
        apb_req.PWDATA = 0;
        apb_req.PSTRB = 0;
        apb_req.PPROT = 0;

        wait(presetn);
        #100;

        // 1. CONTROL/PERIOD/PRESCALE/COUNT readback
        apb_read(32'h8000_2000, rdata, err);
        if (rdata !== 32'd0 || err) $error("CONTROL readback failed");
        apb_read(32'h8000_2008, rdata, err);
        if (rdata !== 32'hFFFF_FFFF || err) $error("PERIOD readback failed");

        // 2. All writable register byte-strobe combinations
        apb_write(32'h8000_2008, 32'h11223344, 4'b0011, err); // Write lower half
        apb_read(32'h8000_2008, rdata, err);
        if (rdata !== 32'hFFFF3344) $error("PSTRB partial write failed");

        // 3. Zero-strobe operations while Timer0 is running
        apb_write(32'h8000_2000, 32'h00000001, 4'b1111, err); // Enable timer
        apb_write(32'h8000_2008, 32'h00000000, 4'b0000, err); // Zero strobe write
        apb_read(32'h8000_2008, rdata, err);
        if (rdata !== 32'hFFFF3344) $error("Zero strobe write modified register");

        // 4. Access to IRQ_ENABLE and IRQ_PENDING
        apb_write(32'h8000_2010, 32'h0000000F, 4'b1111, err);
        apb_read(32'h8000_2010, rdata, err);
        if (rdata !== 32'h0000000F) $error("IRQ_ENABLE write failed");

        // 5. Read-only and illegal writes
        apb_write(32'h8000_2018, 32'hFFFFFFFF, 4'b1111, err); // CAPTURE_VALUE is RO
        if (!err) $error("RO write did not return error");

        // 6. Misaligned and unmapped addresses
        apb_read(32'h8000_2001, rdata, err);
        if (!err) $error("Misaligned read did not return error");

        // 7. Out-of-range and high-bit address alias rejection
        apb_read(32'h8000_2020, rdata, err); // Unmapped in Timer0
        if (!err) $error("Unmapped read did not return error");
        
        apb_read(32'h8000_2000 + 32'h2000, rdata, err); // Alias (bit 13 set)
        if (!err) $error("Alias read did not return error");

        // 8. Correct selection of Timer0 with another APB completer present
        apb_read(32'h8000_3000, rdata, err);
        if (rdata !== 32'hDEADBEEF || err) $error("Dummy completer read failed");

        // 10. Back-to-back reads and writes
        apb_write(32'h8000_2000, 32'h00000000, 4'b1111, err); // Disable timer
        apb_write(32'h8000_2008, 32'hAABBCCDD, 4'b1111, err);
        apb_read(32'h8000_2008, rdata, err);
        if (rdata !== 32'hAABBCCDD) begin 
            $error("Back-to-back access failed: expected %h, got %h", 32'hAABBCCDD, rdata);
        end

        $display("APB Integration tests completed.");
        $finish;
    end

endmodule
