`timescale 1ns/1ps

`include "ahb_if.sv"

`include "bus_protocol_if.sv"
`include "plic_if.sv"

module peripheral_subsystem_tb;

    logic hclk;
    logic hresetn;
    logic pclk;
    logic presetn;

    ahb_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) ahb (.HCLK(hclk), .HRESETn(hresetn));

    // Connect HREADY to HREADYOUT since there is only one slave
    assign ahb.HREADY = ahb.HREADYOUT;

    // GPIOs
    logic [31:0] gpio0_in, gpio0_out, gpio0_oe, gpio0_pu, gpio0_pd;
    logic [15:0] gpio1_in, gpio1_out, gpio1_oe, gpio1_pu, gpio1_pd;
    logic [6:0]  gpio2_in, gpio2_out, gpio2_oe, gpio2_pu, gpio2_pd;
    logic [0:0]  gpio3_in, gpio3_out, gpio3_oe, gpio3_pu, gpio3_pd;

    // PWM and Timer
    logic [3:0] pwm_out, pwm_oe;
    logic timer_capture;

    // IRQs
    logic gpio0_irq, gpio1_irq, gpio2_irq, gpio3_irq, pwm0_irq, timer0_irq;

    peripheral_subsystem dut (
        .hclk(hclk), .hresetn(hresetn), .pclk(pclk), .presetn(presetn),
        .ahb(ahb.subordinate),
        .gpio0_in, .gpio0_out, .gpio0_oe, .gpio0_pu, .gpio0_pd,
        .gpio1_in, .gpio1_out, .gpio1_oe, .gpio1_pu, .gpio1_pd,
        .gpio2_in, .gpio2_out, .gpio2_oe, .gpio2_pu, .gpio2_pd,
        .gpio3_in, .gpio3_out, .gpio3_oe, .gpio3_pu, .gpio3_pd,
        .pwm_out, .pwm_oe, .timer_capture,
        .gpio0_irq, .gpio1_irq, .gpio2_irq, .gpio3_irq, .pwm0_irq, .timer0_irq
    );

    // Clocks
    initial begin
        hclk = 0;
        forever #5 hclk = ~hclk; // 100 MHz
    end
    
    initial begin
        pclk = 0;
        forever #40 pclk = ~pclk; // 12.5 MHz
    end

    // PLIC Integration
    bus_protocol_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) plic_bus();
    plic_if irq_if();
    
    assign irq_if.irq_source = {25'd0, timer0_irq, pwm0_irq, gpio3_irq, gpio2_irq, gpio1_irq, gpio0_irq};

    plic u_plic (
        .clk(hclk),
        .nrst(hresetn),
        .bus(plic_bus.peripheral_vital),
        .irq_if(irq_if.plic)
    );

    task automatic plic_write(input logic [31:0] addr, input logic [31:0] data);
        @(posedge hclk);
        #1;
        plic_bus.wen = 1'b1;
        plic_bus.ren = 1'b0;
        plic_bus.addr = addr;
        plic_bus.wdata = data;
        plic_bus.strobe = 4'hF;
        
        while (plic_bus.request_stall) begin
            @(posedge hclk);
            #1;
        end
        @(posedge hclk);
        #1;
        plic_bus.wen = 1'b0;
    endtask

    task automatic plic_read(input logic [31:0] addr, output logic [31:0] data);
        @(posedge hclk);
        #1;
        plic_bus.wen = 1'b0;
        plic_bus.ren = 1'b1;
        plic_bus.addr = addr;
        plic_bus.strobe = 4'h0;
        
        while (plic_bus.request_stall) begin
            @(posedge hclk);
            #1;
        end
        @(posedge hclk);
        data = plic_bus.rdata;
        #1;
        plic_bus.ren = 1'b0;
    endtask

    // AHB Master Tasks
    task automatic ahb_write(input logic [31:0] addr, input logic [31:0] data, input logic [3:0] strb);
        @(posedge hclk);
        #1;
        ahb.HSEL = 1'b1;
        ahb.HTRANS = 2'b10; // NONSEQ
        ahb.HADDR  = addr;
        ahb.HWRITE = 1'b1;
        ahb.HSIZE  = 3'b010; // Word
        ahb.HWSTRB = strb;
        
        @(posedge hclk);
        #1;
        // Now it's the data phase! Set HWDATA immediately.
        ahb.HTRANS = 2'b00; // IDLE for next cycle
        ahb.HWDATA = data;
        
        while (!ahb.HREADYOUT) begin
            @(posedge hclk);
            #1;
        end
    endtask

    task automatic ahb_read(input logic [31:0] addr, output logic [31:0] data, output logic err);
        @(posedge hclk);
        #1;
        ahb.HSEL = 1'b1;
        ahb.HTRANS = 2'b10;
        ahb.HADDR  = addr;
        ahb.HWRITE = 1'b0;
        ahb.HSIZE  = 3'b010;
        ahb.HWSTRB = 4'b0000;
        
        @(posedge hclk);
        #1;
        ahb.HTRANS = 2'b00;
        
        while (!ahb.HREADYOUT) begin
            @(posedge hclk);
            #1;
        end
        data = ahb.HRDATA;
        err = ahb.HRESP;
    endtask

    logic [31:0] rdata;
    logic rerr;

    initial begin
        // Setup Negative Test Argument
        int expect_failure;
        if ($value$plusargs("EXPECT_FAILURE=%d", expect_failure)) begin
            // We just let it run. If we expect failure, we expect it to hit a $fatal or $error.
        end else begin
            expect_failure = 0;
        end

        hresetn = 0;
        presetn = 0;
        
        ahb.HSEL = 0;
        ahb.HTRANS = 0;
        ahb.HADDR = 0;
        ahb.HWRITE = 0;
        ahb.HSIZE = 0;
        ahb.HWDATA = 0;
        ahb.HWSTRB = 0;
        
        timer_capture = 0;
        gpio0_in = 0; gpio1_in = 0; gpio2_in = 0; gpio3_in = 0;

        #100;
        hresetn = 1;
        presetn = 1;
        #200;

        // Test 1: GPIO0 - 3 consecutively (cross-target)
        ahb_write(32'h8000_0004, 32'hA1A2A3A4, 4'b1111); // GPIO0 OUT
        ahb_write(32'h8000_0104, 32'h0000B1B2, 4'b1111); // GPIO1 OUT (16 bit)
        ahb_write(32'h8000_0204, 32'h000000C1, 4'b1111); // GPIO2 OUT (7 bit)
        ahb_write(32'h8000_0304, 32'h00000001, 4'b1111); // GPIO3 OUT (1 bit)

        ahb_read(32'h8000_0004, rdata, rerr);
        if (rdata !== 32'hA1A2A3A4) $error("GPIO0 read mismatch");
        ahb_read(32'h8000_0104, rdata, rerr);
        if (rdata !== 32'h0000B1B2) $error("GPIO1 read mismatch: %h", rdata);
        
        #200;
        if (gpio0_out !== 32'hA1A2A3A4) $error("GPIO0 out pin mismatch");
        if (gpio1_out !== 16'hB1B2) $error("GPIO1 out pin mismatch"); 

        // Test 2: PWM Global Registers
        ahb_write(32'h8000_1100, 32'h0000_000F, 4'b1111); // IRQ_ENABLE
        ahb_read(32'h8000_1100, rdata, rerr);
        if (rdata !== 32'h0000_000F) $error("PWM IRQ_ENABLE read mismatch");
        
        // Test highest register addresses
        ahb_read(32'h8000_0044, rdata, rerr);
        if (rerr) $error("GPIO0 highest register read error at 0x44");

        ahb_read(32'h8000_1108, rdata, rerr); // PWM_INFO
        if (rerr) $error("PWM0 highest register read error at 0x108");

        ahb_read(32'h8000_201C, rdata, rerr); // Timer0 highest register
        if (rerr) $error("Timer0 highest register read error at 0x1C");

        // Test 3: Unmapped hole
        ahb_read(32'h8000_0400, rdata, rerr);
        if (!rerr) $error("Expected HRESP error on unmapped read");

        // Test 4: Timer0 Capture
        ahb_write(32'h8000_2004, 32'h0000_FFFF, 4'b1111); // Load
        ahb_write(32'h8000_2000, 32'h0000_0001, 4'b1111); // Enable
        #100;
        timer_capture = 1; // trigger capture
        #100;
        timer_capture = 0;
        ahb_read(32'h8000_2018, rdata, rerr); // Capture value
        if (rerr) $error("Timer capture read error");

        // Test 5: IO Mux (0x8000_6000)
        ahb_write(32'h8000_6000, 32'h12345678, 4'b1111);
        ahb_read(32'h8000_6000, rdata, rerr);
        if (rdata !== 32'h12345678) $error("IO Mux read mismatch: %h", rdata);

        // Negative test trigger
        if (expect_failure) begin
            ahb_write(32'h8000_111C, 32'h0000_0000, 4'b1111); // invalid PWM register
            ahb_read(32'h8000_111C, rdata, rerr);
            if (rerr) $error("Intentional failure triggered"); // this will abort
        end

        // Test 6: PLIC routing
        // Enable GPIO0 (source 1)
        plic_write(32'h00_2000, 32'h0000_0002); // Enable source 1 for target 0
        plic_write(32'h20_0000, 32'h0000_0000); // Set threshold to 0
        plic_write(32'h00_0004, 32'h0000_0001); // Set source 1 priority to 1

        ahb_write(32'h8000_0024, 32'h0000_0001, 4'b1111); // irq_rise_en for GPIO0 pin 0
        #100;
        gpio0_in = 32'h1; // Rising edge on pin 0
        
        #1000;
        // Check if irq_if.irq_target asserted
        if (!irq_if.irq_target) $error("PLIC target interrupt did not assert!");
        
        // Claim the interrupt
        plic_read(32'h20_0004, rdata);
        if (rdata !== 32'h0000_0001) $error("PLIC claim read mismatch. Got %h", rdata);
        
        // Clear GPIO interrupt pending (RW1C at 0x34)
        ahb_write(32'h8000_0034, 32'h0000_0001, 4'b1111);

        // Complete the interrupt
        plic_write(32'h20_0004, 32'h0000_0001);

        $display("Integration Subsystem tests passed.");
        $finish;
    end

    // Timeout watchdog
    initial begin
        #50000;
        $error("Timeout!");
        $finish;
    end

endmodule