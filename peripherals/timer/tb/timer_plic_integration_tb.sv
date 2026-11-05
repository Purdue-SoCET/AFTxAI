`timescale 1ns/1ps

module timer_plic_integration_tb;
    initial begin #500000; $fatal(1, "Test timeout"); end

    logic clk, rst_n;

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz
    end

    // Reset generation
    initial begin
        rst_n = 0;
        #100 rst_n = 1;
    end

    // APB Interface for Timer
    apb_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) apb_req (.PCLK(clk), .PRESETn(rst_n));

    // Bus Protocol Interface for PLIC
    bus_protocol_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) plic_bus ();

    // PLIC Interface
    plic_if irq_if ();

    // Tie off unused PLIC sources
    assign irq_if.irq_source[15:7] = '0;
    assign irq_if.irq_source[5:1] = '0;
    assign irq_if.irq_source[31:16] = '0;

    // Timer Wrapper
    logic capture_i;
    logic irq_o;
    timer_apb_wrapper #(
        .BASE_ADDR(32'h8000_2000)
    ) u_timer_wrapper (
        .apb(apb_req.completer),
        .capture_i(capture_i),
        .irq_o(irq_o)
    );

    // Connect Timer IRQ to PLIC source 6
    assign irq_if.irq_source[6] = irq_o;

    // PLIC
    plic u_plic (
        .clk(clk),
        .nrst(rst_n),
        .bus(plic_bus.peripheral_vital),
        .irq_if(irq_if.plic)
    );

    // BFM Tasks for APB
    task apb_write(input logic [31:0] addr, input logic [31:0] data, input logic [3:0] strb);
        @(posedge clk);
        apb_req.PADDR <= addr;
        apb_req.PWRITE <= 1'b1;
        apb_req.PSEL <= 1'b1;
        apb_req.PENABLE <= 1'b0;
        apb_req.PWDATA <= data;
        apb_req.PSTRB <= strb;
        @(posedge clk);
        apb_req.PENABLE <= 1'b1;
        @(posedge clk);
        while (!apb_req.PREADY) @(posedge clk);
        apb_req.PSEL <= 1'b0;
        apb_req.PENABLE <= 1'b0;
    endtask

    // BFM Tasks for PLIC Bus
    task plic_write(input logic [31:0] addr, input logic [31:0] data);
        @(posedge clk);
        plic_bus.wen <= 1'b1;
        plic_bus.ren <= 1'b0;
        plic_bus.addr <= addr;
        plic_bus.wdata <= data;
        plic_bus.strobe <= 4'hF;
        @(posedge clk);
        while (plic_bus.request_stall) @(posedge clk);
        plic_bus.wen <= 1'b0;
    endtask

    task plic_read(input logic [31:0] addr, output logic [31:0] data);
        @(posedge clk);
        plic_bus.wen <= 1'b0;
        plic_bus.ren <= 1'b1;
        plic_bus.addr <= addr;
        @(posedge clk);
        while (plic_bus.request_stall) @(posedge clk);
        data = plic_bus.rdata;
        plic_bus.ren <= 1'b0;
    endtask

    logic [31:0] rdata;

    initial begin
        capture_i = 0;
        
        apb_req.PADDR = 0;
        apb_req.PWRITE = 0;
        apb_req.PSEL = 0;
        apb_req.PENABLE = 0;
        apb_req.PWDATA = 0;
        apb_req.PSTRB = 0;
        apb_req.PPROT = 0;

        plic_bus.wen = 0;
        plic_bus.ren = 0;
        plic_bus.addr = 0;
        plic_bus.wdata = 0;
        plic_bus.strobe = 0;

        wait(rst_n);
        #100;

        // 1. Configure PLIC
        // Priority for source 6 = 7
        plic_write(32'h00_0018, 32'h00000007); // 6 * 4 = 24 = 0x18
        
        // Enable for source 6
        plic_write(32'h00_2000, 32'h00000040); // bit 6
        
        // Threshold = 0
        plic_write(32'h20_0000, 32'h00000000);

        // 2. Configure Timer to generate MATCH interrupt immediately
        apb_write(32'h8000_2008, 32'h0000000A, 4'hF); // PERIOD = 10
        apb_write(32'h8000_2010, 32'h00000001, 4'hF); // IRQ_ENABLE = 1 (MATCH)
        apb_write(32'h8000_2000, 32'h00000003, 4'hF); // EN=1, MODE=1 (One-shot)

        // Wait for Timer MATCH interrupt
        wait(irq_o == 1);
        @(posedge clk);
        
        // Wait for PLIC to assert irq_target
        #20;
        if (irq_if.irq_target !== 1'b1) $error("PLIC target not asserted");

        // 3. Claim interrupt
        plic_read(32'h20_0004, rdata);
        if (rdata !== 32'd6) $error("Claim ID mismatch");

        // 4. Check PLIC pending is cleared (but irq_o is still active!)
        // Wait, PLIC target should be 0 because we claimed it and max_id = 0 now (pending cleared)
        @(posedge clk);
        @(posedge clk); // Wait one more cycle for irq_target to be registered out
        #1;
        if (irq_if.irq_target !== 1'b0) $error("PLIC target not deasserted after claim");

        // 5. Complete interrupt
        plic_write(32'h20_0004, 32'd6);
        @(posedge clk);

        // 6. Because Timer IRQ is level-sensitive and we haven't cleared it, PLIC should re-trigger
        // Since irq_source is high and gateway is released, pending should go high again.
        #20;
        if (irq_if.irq_target !== 1'b1) $error("PLIC target not reasserted for level IRQ");

        // 7. Clear Timer IRQ
        apb_write(32'h8000_2014, 32'h00000001, 4'hF); // W1C
        @(posedge clk);
        if (irq_o !== 1'b0) $error("Timer IRQ not cleared");

        // 8. Re-claim and complete to clear the re-triggered PLIC
        plic_read(32'h20_0004, rdata);
        plic_write(32'h20_0004, 32'd6);
        @(posedge clk);
        
        #20;
        if (irq_if.irq_target !== 1'b0) $error("PLIC target still asserted after clearing source");

        $display("PLIC Integration tests completed.");
        $finish;
    end

endmodule
