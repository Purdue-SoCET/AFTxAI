module gpio_tb #(
    parameter int GPIO_WIDTH = 32
);

    logic        pclk = 0;
    logic        presetn = 0;
    logic [7:0]  paddr = '0;
    logic        psel = 0;
    logic        penable = 0;
    logic        pwrite = 0;
    logic [31:0] pwdata = '0;
    logic [3:0]  pstrb = '0;
    logic [2:0]  pprot = '0;
    logic [31:0] prdata;
    logic        pready;
    logic        pslverr;

    logic [GPIO_WIDTH-1:0] gpio_in_i = '0;
    logic [GPIO_WIDTH-1:0] gpio_out_o;
    logic [GPIO_WIDTH-1:0] gpio_oe_o;
    logic [GPIO_WIDTH-1:0] gpio_pull_up_o;
    logic [GPIO_WIDTH-1:0] gpio_pull_down_o;
    logic        irq_o;

    gpio_apb #(
        .GPIO_WIDTH(GPIO_WIDTH)
    ) dut (
        .pclk(pclk),
        .presetn(presetn),
        .paddr(paddr),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .pstrb(pstrb),
        .pprot(pprot),
        .prdata(prdata),
        .pready(pready),
        .pslverr(pslverr),
        .gpio_in_i(gpio_in_i),
        .gpio_out_o(gpio_out_o),
        .gpio_oe_o(gpio_oe_o),
        .gpio_pull_up_o(gpio_pull_up_o),
        .gpio_pull_down_o(gpio_pull_down_o),
        .irq_o(irq_o)
    );

    always #5 pclk = ~pclk;

    task apb_write(input [7:0] addr, input [31:0] data, input [3:0] strb = 4'hF, output logic err);
        @(posedge pclk);
        paddr = addr;
        pwrite = 1'b1;
        pwdata = data;
        pstrb = strb;
        psel = 1'b1;
        penable = 1'b0;
        @(posedge pclk);
        penable = 1'b1;
        @(posedge pclk);
        err = pslverr;
        psel = 1'b0;
        penable = 1'b0;
    endtask

    task apb_read(input [7:0] addr, output logic [31:0] data, output logic err, input [3:0] strb = 4'h0);
        @(posedge pclk);
        paddr = addr;
        pwrite = 1'b0;
        pstrb = strb;
        psel = 1'b1;
        penable = 1'b0;
        @(posedge pclk);
        penable = 1'b1;
        @(posedge pclk);
        data = prdata;
        err = pslverr;
        psel = 1'b0;
        penable = 1'b0;
    endtask

    logic [31:0] rdata;
    logic err;
    logic [31:0] active_mask;

    initial begin
        /* verilator lint_off WIDTHTRUNC */
        /* verilator lint_off WIDTHEXPAND */
        // Timeout
        fork
            begin
                #50000;
                $fatal(1, "TIMEOUT");
            end
        join_none

        active_mask = (GPIO_WIDTH == 32) ? 32'hFFFF_FFFF : ((1 << GPIO_WIDTH) - 1);

        // T01: Reset while clocking and without a clock edge
        presetn = 0;
        gpio_in_i = active_mask; // Hold high through reset
        #22; 
        if (gpio_out_o !== 0 || gpio_oe_o !== 0 || irq_o !== 0) $fatal(1, "T01 Failed");
        
        // T02: Reset deasserted on legal boundary
        @(posedge pclk);
        presetn = 1;
        #100;
        apb_read(8'h34, rdata, err); // rise pending
        if (rdata !== 0) $fatal(1, "T02 Failed: Artificial rise event");

        // T03: APB SETUP-only transaction
        @(posedge pclk);
        paddr = 8'h04;
        pwrite = 1;
        pwdata = 32'hFFFF_FFFF;
        pstrb = 4'hF;
        psel = 1;
        penable = 0;
        @(posedge pclk);
        psel = 0;
        penable = 0;
        apb_read(8'h04, rdata, err);
        if (rdata !== 0) $fatal(1, "T03 Failed");

        // T04 & T05: Back-to-back write and read
        apb_write(8'h08, 32'hFFFF_FFFF, 4'hF, err); // DIR
        apb_write(8'h04, 32'hA5A5_5A5A, 4'hF, err); // DATA_OUT
        apb_read(8'h04, rdata, err);
        if (rdata !== (32'hA5A5_5A5A & active_mask) || err !== 0) $fatal(1, "T04 Failed");
        if (gpio_out_o !== (32'hA5A5_5A5A & active_mask) || gpio_oe_o !== active_mask) $fatal(1, "T04 OE/OUT Failed");

        // T06: PSTRB combinations
        apb_write(8'h04, 32'hFFFF_FFFF, 4'b0011, err);
        apb_read(8'h04, rdata, err);
        if (rdata !== (32'hA5A5_FFFF & active_mask)) $fatal(1, "T06 Failed");

        // T07: OUT_SET / OUT_CLEAR / OUT_TOGGLE
        apb_write(8'h0C, 32'h0000_F000, 4'hF, err); // SET
        apb_write(8'h10, 32'h0000_000F, 4'hF, err); // CLEAR
        apb_write(8'h14, 32'h0000_00F0, 4'hF, err); // TOGGLE
        apb_read(8'h04, rdata, err);
        if (rdata !== (32'hA5A5_FF00 & active_mask)) $fatal(1, "T07 Failed: %x", rdata);

        // T08: Non-word-aligned, unmapped, WO-read, RO-write
        apb_write(8'h01, 32'hFFFF_FFFF, 4'hF, err);
        if (err !== 1) $fatal(1, "T08 Failed non-word-aligned");
        apb_write(8'h48, 32'hFFFF_FFFF, 4'hF, err);
        if (err !== 1) $fatal(1, "T08 Failed unmapped");
        apb_read(8'h0C, rdata, err); // WO
        if (err !== 1) $fatal(1, "T08 Failed WO read");
        apb_write(8'h00, 32'hFFFF_FFFF, 4'hF, err); // RO
        if (err !== 1) $fatal(1, "T08 Failed RO write");
        
        // Requester drives pstrb!=0 on read
        apb_read(8'h04, rdata, err, 4'hF);
        if (err !== 1) $fatal(1, "T08 Failed PSTRB!=0 read");

        // T09: PULL conflict
        apb_write(8'h18, 32'h0000_0001, 4'hF, err); // pull up
        apb_write(8'h1C, 32'h0000_0001, 4'hF, err); // pull down conflict
        if (err !== 1) $fatal(1, "T09 Failed conflict not caught");
        apb_read(8'h1C, rdata, err);
        if ((rdata & 1) != 0) $fatal(1, "T09 Failed conflict altered state");

        // T10: Open Drain
        apb_write(8'h20, 32'hFFFF_FFFF, 4'hF, err); // open drain all
        apb_write(8'h04, 32'h0000_0001, 4'hF, err); // data out
        #1;
        if (gpio_oe_o[0] !== 0 || gpio_out_o[0] !== 0) $fatal(1, "T10 Failed OD release");
        apb_write(8'h04, 32'h0000_0000, 4'hF, err);
        #1;
        if (gpio_oe_o[0] !== 1 || gpio_out_o[0] !== 0) $fatal(1, "T10 Failed OD sink");
        apb_write(8'h20, 32'h0, 4'hF, err); // normal push-pull

        // T11: Sync senses pad
        gpio_in_i = active_mask;
        #30;
        apb_read(8'h00, rdata, err);
        if (rdata !== active_mask) $fatal(1, "T11 Failed in read");

        // T12-T17, T25: Interrupts
        gpio_in_i = 0;
        #30;
        apb_write(8'h24, 32'hFFFF_FFFF, 4'hF, err); // rise en
        apb_write(8'h28, 32'hFFFF_FFFF, 4'hF, err); // fall en
        apb_write(8'h34, 32'hFFFF_FFFF, 4'hF, err); // clear rise
        apb_write(8'h38, 32'hFFFF_FFFF, 4'hF, err); // clear fall
        
        gpio_in_i = active_mask; // trigger rise
        #40;
        apb_read(8'h34, rdata, err);
        if (rdata !== active_mask) $fatal(1, "T12 Failed rise pending");
        if (irq_o !== 1) $fatal(1, "T12 Failed IRQ out");

        apb_write(8'h34, 32'hFFFF_FFFF, 4'hF, err); // clear rise
        apb_read(8'h34, rdata, err);
        if (rdata !== 0 || irq_o !== 0) $fatal(1, "T13 Failed W1C");
        
        // T14: Simultaneous event and clear
        // We need to trigger an event at the exact clock cycle the W1C applies.
        // Setup: clear all
        apb_write(8'h34, 32'hFFFF_FFFF, 4'hF, err);
        apb_write(8'h38, 32'hFFFF_FFFF, 4'hF, err);
        gpio_in_i = 0;
        #30;
        // Launch a write to clear rise pending
        fork
            apb_write(8'h34, 32'hFFFF_FFFF, 4'hF, err);
            begin
                // The write task takes ~3 cycles. We want to toggle gpio_in right before the penable cycle.
                #15; 
                gpio_in_i = active_mask; // triggers rise event
            end
        join
        #20;
        apb_read(8'h34, rdata, err);
        if (rdata !== active_mask) $fatal(1, "T14 Failed: SET did not win over W1C");

        // T15, T16: Level Interrupts
        apb_write(8'h24, 32'h0, 4'hF, err); // disable edge irqs
        apb_write(8'h28, 32'h0, 4'hF, err);
        apb_write(8'h34, 32'hFFFF_FFFF, 4'hF, err); // clear pending
        apb_write(8'h38, 32'hFFFF_FFFF, 4'hF, err);
        
        apb_write(8'h2C, 32'h1, 4'hF, err); // IRQ_HIGH_EN for bit 0
        gpio_in_i = 0;
        #30;
        if (irq_o !== 0) $fatal(1, "T15 Failed: IRQ should be low");
        gpio_in_i = 1;
        #30;
        if (irq_o !== 1) $fatal(1, "T15 Failed: IRQ should be high");
        gpio_in_i = 0;
        #30;
        if (irq_o !== 0) $fatal(1, "T15/T25 Failed: IRQ should drop automatically (level status)");
        apb_write(8'h2C, 32'h0, 4'hF, err); 
        
        apb_write(8'h30, 32'h1, 4'hF, err); // IRQ_LOW_EN for bit 0
        gpio_in_i = 1;
        #30;
        if (irq_o !== 0) $fatal(1, "T16 Failed: IRQ should be low");
        gpio_in_i = 0;
        #30;
        if (irq_o !== 1) $fatal(1, "T16 Failed: IRQ should be high");
        apb_write(8'h30, 32'h0, 4'hF, err);

        // T17: Edge capture while masked
        apb_write(8'h24, 32'h0, 4'hF, err); // rise EN = 0
        apb_write(8'h34, 32'hFFFF_FFFF, 4'hF, err); // clear pending
        gpio_in_i = 0;
        #30;
        gpio_in_i = 1; // rise event
        #30;
        if (irq_o !== 0) $fatal(1, "T17 Failed: IRQ asserted while masked");
        apb_read(8'h34, rdata, err);
        if ((rdata & 1) == 0) $fatal(1, "T17 Failed: Event not captured in pending");
        apb_write(8'h24, 32'h1, 4'hF, err); // unmask
        #10;
        if (irq_o !== 1) $fatal(1, "T17 Failed: IRQ did not assert after unmask");

        // T18: Multiple events across multiple pins
        if (GPIO_WIDTH > 1) begin
            apb_write(8'h34, 32'hFFFF_FFFF, 4'hF, err);
            apb_write(8'h38, 32'hFFFF_FFFF, 4'hF, err);
            gpio_in_i = active_mask; // all high
            #30;
            gpio_in_i = ~32'h2 & active_mask; // bit 1 falls
            #30;
            gpio_in_i = (~32'h2 | 32'h1) & active_mask; // bit 1 stays low, bit 0 already high, wait, let's just make bit 0 fall and bit 1 rise
            gpio_in_i = 32'h2;
            #30;
            apb_read(8'h34, rdata, err); // bit 1 rose
            if ((rdata & 2) == 0) $fatal(1, "T18 Failed: bit 1 rise missing");
            apb_read(8'h38, rdata, err); // bit 0 fell
            if ((rdata & 1) == 0) $fatal(1, "T18 Failed: bit 0 fall missing");
        end

        // T19/T20: Pull-up / Pull-down readback and OE states
        apb_write(8'h18, 32'h0, 4'hF, err); // pull up 0
        apb_write(8'h1C, 32'h0, 4'hF, err); // pull down 0
        apb_write(8'h18, 32'h2, 4'hF, err); // bit 1 pull up
        apb_read(8'h18, rdata, err);
        if (GPIO_WIDTH > 1 && (rdata & 2) == 0) $fatal(1, "T19/T20 Failed: pull-up state");
        apb_write(8'h18, 32'h0, 4'hF, err); 
        
        // T21: GPIO_INFO
        apb_read(8'h44, rdata, err);
        if (rdata[7:0] !== 8'(GPIO_WIDTH) || rdata[10:8] !== 3'b111) $fatal(1, "T21 Failed");
        apb_write(8'h44, 32'h0, 4'hF, err);
        if (err !== 1) $fatal(1, "T21 Failed write to INFO");

        // T24: Second reset
        presetn = 0;
        #10;
        if (irq_o !== 0 || gpio_oe_o !== 0) $fatal(1, "T24 Failed reset");
        presetn = 1;

        $display("ALL TESTS PASSED FOR WIDTH %0d", GPIO_WIDTH);
        /* verilator lint_on WIDTHTRUNC */
        /* verilator lint_on WIDTHEXPAND */
        $finish;
    end

endmodule
