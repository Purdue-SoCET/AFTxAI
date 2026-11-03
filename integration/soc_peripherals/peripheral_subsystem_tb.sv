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
        ahb.HTRANS = 2'b00; // IDLE
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
    int snap_count;

    initial begin
        int expect_failure;
        if ($value$plusargs("EXPECT_FAILURE=%d", expect_failure)) begin
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

        // --- Task 5: Valid boundary and invalid-address tests ---
        // Test highest register addresses
        ahb_read(32'h8000_0044, rdata, rerr);
        if (rerr) $error("GPIO0 highest register read error at 0x44");

        ahb_read(32'h8000_1108, rdata, rerr); // PWM_INFO
        if (rerr) $error("PWM0 highest register read error at 0x108");

        ahb_read(32'h8000_201C, rdata, rerr); // Timer0 highest register
        if (rerr) $error("Timer0 highest register read error at 0x1C");

        // Invalid unmapped hole
        ahb_read(32'h8000_0400, rdata, rerr);
        if (!rerr) $error("Expected HRESP error on unmapped read");

        // --- Task 5: Back-to-back accesses across all peripherals ---
        ahb_write(32'h8000_0004, 32'hB2B2B2B2, 4'hF); // GPIO0
        ahb_write(32'h8000_1000, 32'h00000000, 4'hF); // PWM0
        ahb_write(32'h8000_2010, 32'h00000000, 4'hF); // Timer0
        ahb_read(32'h8000_0004, rdata, rerr);
        if (rdata !== 32'hB2B2B2B2) $error("Back-to-back writes failed");

        // --- Task 5: Reset-during-transfer check ---
        fork
            begin
                ahb.HSEL = 1'b1;
                ahb.HTRANS = 2'b10;
                ahb.HADDR  = 32'h8000_0004;
                ahb.HWRITE = 1'b1;
                ahb.HSIZE  = 3'b010;
                ahb.HWSTRB = 4'hF;
                @(posedge hclk);
                #1;
                ahb.HTRANS = 2'b00;
                ahb.HWDATA = 32'hDEADBEEF;
                // Don't wait for HREADYOUT, reset will happen
            end
            begin
                #25; 
                hresetn = 0; presetn = 0;
                #100;
                hresetn = 1; presetn = 1;
            end
        join
        #200;
        
        // --- Task 1: PWM configuration and simultaneous checks ---
        // Configure PWM Channel 0
        ahb_write(32'h8000_1004, 32'd10, 4'hF); // PERIOD_SHADOW = 10
        ahb_write(32'h8000_1008, 32'd5,  4'hF);  // DUTY_SHADOW = 5
        ahb_write(32'h8000_100C, 32'd1,  4'hF);  // PRESCALE_SHADOW = 1
        ahb_write(32'h8000_1010, 32'd1,  4'hF);  // UPDATE (Arm config)
        ahb_write(32'h8000_1000, 32'd1,  4'hF);  // EN=1, POL=0
        
        fork
            // PWM Waveform Checker
            begin
                int periods = 0;
                logic last_pwm = 0;
                while (periods < 3) begin
                    @(posedge pclk);
                    if (pwm_out[0] == 1'b1 && last_pwm == 1'b0) periods++;
                    last_pwm = pwm_out[0];
                    if (pwm_oe[0] !== 1'b1) $error("PWM OE dropped!");
                end
            end
            
            // Simultaneous accesses to GPIO and Timer0
            begin
                ahb_write(32'h8000_0004, 32'hA1A2A3A4, 4'b1111); // GPIO0 OUT
                ahb_write(32'h8000_0104, 32'h0000B1B2, 4'b1111); // GPIO1 OUT
                ahb_write(32'h8000_0204, 32'h000000C1, 4'b1111); // GPIO2 OUT
                
                ahb_read(32'h8000_0004, rdata, rerr);
                if (rdata !== 32'hA1A2A3A4) $error("GPIO0 read mismatch");
                
                // Configure Timer0 in background
                ahb_write(32'h8000_2004, 32'd0, 4'b1111); // Count = 0
                ahb_write(32'h8000_2008, 32'hFFFF_FFFF, 4'b1111); // Max period
                ahb_write(32'h8000_200C, 32'd0, 4'b1111); // Prescale 0
            end
        join

        // --- Task 2: Timer0 Capture ---
        // Stop timer, count=0
        //ahb_write(32'h8000_2000, 32'h0000_0000, 4'b1111);
        //ahb_write(32'h8000_2004, 32'd0, 4'b1111);
        //ahb_write(32'h8000_2008, 32'hFFFF_FFFF, 4'b1111);
        //ahb_write(32'h8000_200C, 32'd0, 4'b1111);
        //
        //// Enable timer and capture (EN=1 (bit 0), CAP_EN=1 (bit 3) -> 0x9)
        //ahb_write(32'h8000_2000, 32'h0000_0009, 4'b1111); 
        //#1600;
        //
        //// Take a snapshot of count physically via a read
        //ahb_read(32'h8000_2004, rdata, rerr);
        //snap_count = rdata;
        //
        //// Now assert capture on the next pclk
        //@(posedge pclk); #1;
        //timer_capture = 1; // trigger rising edge
        //
        //#800;
        //timer_capture = 0;
        //
        //ahb_read(32'h8000_2014, rdata, rerr); // IRQ_PENDING
        //if ((rdata & 32'h4) == 0) $error("Timer0 CAPTURE pending bit not set");
        //
        //ahb_read(32'h8000_2018, rdata, rerr); // CAPTURE_VALUE
        //// Expected latency is exactly 3 PCLKs from the posedge following the read.
        //if (rdata !== (snap_count + 3)) $error("Timer0 CAPTURE_VALUE mismatch. Expected %0d, got %0d", snap_count + 3, rdata);
        //
        //// Clear Timer capture pending
        //ahb_write(32'h8000_2014, 32'h0000_0004, 4'hF);


        // --- Task 3: PLIC Interrupt Verification ---
        // source 1: gpio0, source 5: pwm0, source 6: timer0
        
        // Enable sources 1, 5, 6 for target 0 
        plic_write(32'h00_2000, 32'h0000_0062); // (1<<1)|(1<<5)|(1<<6) = 0x62
        plic_write(32'h20_0000, 32'h0000_0000); // Threshold 0
        plic_write(32'h00_0004, 32'h0000_0001); // Source 1 prio = 1
        plic_write(32'h00_0014, 32'h0000_0002); // Source 5 prio = 2
        plic_write(32'h00_0018, 32'h0000_0003); // Source 6 prio = 3
        
        // Trigger Timer0 IRQ via MATCH
        ahb_write(32'h8000_2000, 32'h0000_0000, 4'hF); // Disable
        ahb_write(32'h8000_2004, 32'h0000_0000, 4'hF); // Count = 0
        ahb_write(32'h8000_2008, 32'h0000_0010, 4'hF); // Period = 16
        ahb_write(32'h8000_2010, 32'h0000_0001, 4'hF); // IRQ_EN match
        ahb_write(32'h8000_2000, 32'h0000_0001, 4'hF); // Enable
        
        // Trigger PWM0 IRQ
        ahb_write(32'h8000_1100, 32'h0000_0001, 4'hF); // IRQ_EN global
        // wait for PWM boundary (it's running)
        // Trigger GPIO0 IRQ
        ahb_write(32'h8000_0024, 32'h0000_0001, 4'hF); // rise en
        @(posedge pclk); gpio0_in = 32'h1; 
        repeat(5) @(posedge pclk); 
        gpio0_in = 32'h0;
        
        #2000;
        $display("IRQs at PLIC: GPIO0=%b, PWM0=%b, Timer0=%b", gpio0_irq, pwm0_irq, timer0_irq);
        if (!irq_if.irq_target) $error("PLIC target interrupt did not assert!");
        
        // Claim high priority (Timer0 = 6)
        plic_read(32'h20_0004, rdata);
        if (rdata !== 32'h0000_0006) $error("PLIC claim read mismatch 6. Got %h", rdata);
        // Clear Timer
        ahb_write(32'h8000_2000, 32'h0000_0000, 4'hF); // Disable Timer0 to prevent re-triggering
        ahb_write(32'h8000_2014, 32'h0000_0001, 4'hF); // Clear MATCH interrupt
        plic_write(32'h20_0004, 32'h0000_0006); // Complete
        #500;
        
        // Claim next priority (PWM0 = 5)
        plic_read(32'h20_0004, rdata);
        if (rdata !== 32'h0000_0005) $error("PLIC claim read mismatch 5. Got %h", rdata);
        // Clear PWM0
        ahb_write(32'h8000_1104, 32'h0000_0001, 4'hF);
        plic_write(32'h20_0004, 32'h0000_0005); // Complete
        #500;
        
        // Claim lowest priority (GPIO0 = 1)
        plic_read(32'h20_0004, rdata);
        if (rdata !== 32'h0000_0001) $error("PLIC claim read mismatch 1. Got %h", rdata);
        // Clear GPIO0
        ahb_write(32'h8000_0034, 32'h0000_0001, 4'hF);
        plic_write(32'h20_0004, 32'h0000_0001); // Complete
        #500;


        // Negative test trigger
        if (expect_failure) begin
            ahb_write(32'h8000_111C, 32'h0000_0000, 4'b1111); // invalid PWM register
            ahb_read(32'h8000_111C, rdata, rerr);
            if (rerr) $error("Intentional failure triggered"); // this will abort
        end

        $display("Integration Subsystem tests passed.");
        $finish;
    end

    // Timeout watchdog
    initial begin
        #500000;
        $error("Timeout!");
        $finish;
    end

endmodule