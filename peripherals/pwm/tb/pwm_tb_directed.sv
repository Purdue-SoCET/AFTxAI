`timescale 1ns/1ps

module pwm_tb_directed;
    logic pclk;
    logic presetn;

    // APB4 interface
    logic [11:0] paddr;
    logic psel;
    logic penable;
    logic pwrite;
    logic [31:0] pwdata;
    logic [3:0] pstrb;
    logic [2:0] pprot;
    logic [31:0] prdata;
    logic pready;
    logic pslverr;

    // PWM external outputs
    logic [3:0] pwm_out_o;
    logic [3:0] pwm_oe_o;
    logic irq_o;

    pwm_core #(
        .PWM_CHANNELS(4),
        .ADDR_WIDTH(12),
        .DATA_WIDTH(32)
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
        .pwm_out_o(pwm_out_o),
        .pwm_oe_o(pwm_oe_o),
        .irq_o(irq_o)
    );

    initial begin
        pclk = 0;
        forever #40 pclk = ~pclk; // 12.5 MHz
    end

    int errors = 0;
    int checks = 0;

    task check(input logic condition, input string msg);
        checks++;
        if (!condition) begin
            $error("FAIL: %s at %0t", msg, $time);
            errors++;
        end
    endtask

    task apb_write(input logic [11:0] addr, input logic [31:0] data, input logic [3:0] strb, output logic err);
        @(posedge pclk);
        paddr <= addr;
        psel <= 1;
        penable <= 0;
        pwrite <= 1;
        pwdata <= data;
        pstrb <= strb;
        pprot <= 3'b000;
        @(posedge pclk);
        penable <= 1;
        #1;
        while (!pready) begin
            @(posedge pclk);
            #1;
        end
        err = pslverr;
        @(posedge pclk);
        psel <= 0;
        penable <= 0;
    endtask

    task apb_read(input logic [11:0] addr, output logic [31:0] data, output logic err, input logic [3:0] strb = 4'b0000);
        @(posedge pclk);
        paddr <= addr;
        psel <= 1;
        penable <= 0;
        pwrite <= 0;
        pstrb <= strb; // usually 0 for read
        pprot <= 3'b000;
        @(posedge pclk);
        penable <= 1;
        #1;
        while (!pready) begin
            @(posedge pclk);
            #1;
        end
        data = prdata;
        err = pslverr;
        @(posedge pclk);
        psel <= 0;
        penable <= 0;
    endtask

    task do_reset();
        presetn = 0;
        psel = 0;
        penable = 0;
        pwrite = 0;
        pstrb = 0;
        pwdata = 0;
        paddr = 0;
        pprot = 0;
        repeat(5) @(posedge pclk);
        presetn = 1;
        repeat(5) @(posedge pclk);
    endtask

    initial begin
        logic err;
        logic [31:0] rdata;
        
        do_reset();
        
        // T01: Reset defaults
        apb_read(12'h108, rdata, err);
        check(rdata == {16'h5057, 8'h01, 8'd4}, "T01: PWM_INFO correct");
        
        // T02-T07: APB Permissions and Access
        apb_write(12'h108, 32'hFFFFFFFF, 4'hF, err);
        check(err == 1, "T07: Write to RO PWM_INFO gives PSLVERR");
        
        apb_read(12'h000, rdata, err);
        check(rdata == 32'd0 && err == 0, "T01: CH0 CTRL reset");
        apb_read(12'h004, rdata, err);
        check(rdata == 32'd1 && err == 0, "T01: CH0 PERIOD reset");

        apb_read(12'h010, rdata, err);
        check(err == 1, "T07: Read WO UPDATE gives PSLVERR");
        
        apb_read(12'h01C, rdata, err);
        check(err == 1, "T07: Read reserved gives PSLVERR");

        apb_read(12'h004, rdata, err, 4'hF);
        check(err == 1, "T07: Read with non-zero PSTRB gives PSLVERR");

        // T16, T17: Absent channel
        apb_read(12'h080, rdata, err); // CH4 does not exist for PWM_CHANNELS=4
        check(err == 1, "T16: Absent channel access PSLVERR");

        // T08-T17: Exact waveforms and edges
        apb_write(12'h004, 32'd4, 4'hF, err); // PERIOD=4
        apb_write(12'h008, 32'd1, 4'hF, err); // DUTY=1
        apb_write(12'h00C, 32'd0, 4'hF, err); // PRESCALE=0
        apb_write(12'h000, 32'd1, 4'hF, err); // EN=1
        
        #1;
        check(pwm_out_o[0] == 1, "T09: Phase 0 is high");
        check(pwm_oe_o[0] == 1, "T09: OE is high");
        @(posedge pclk); #1; check(pwm_out_o[0] == 0, "T09: Phase 1 is low");
        @(posedge pclk); #1; check(pwm_out_o[0] == 0, "T09: Phase 2 is low");
        @(posedge pclk); #1; check(pwm_out_o[0] == 0, "T09: Phase 3 is low");
        @(posedge pclk); #1; check(pwm_out_o[0] == 1, "T09: Phase 0 next cycle is high");
        
        // Disable
        apb_write(12'h000, 32'd0, 4'hF, err);
        #1; check(pwm_out_o[0] == 0 && pwm_oe_o[0] == 0, "T08: EN 1->0 safe off");
        
        do_reset();
        
        // T10: Duty 0%, 50%, 100%
        apb_write(12'h004, 32'd4, 4'hF, err);
        apb_write(12'h008, 32'd0, 4'hF, err);
        apb_write(12'h000, 32'd1, 4'hF, err);
        #1; check(pwm_out_o[0] == 0, "T10: Duty 0% phase 0 is low");
        @(posedge pclk); #1; check(pwm_out_o[0] == 0, "T10: Duty 0% phase 1 is low");
        apb_write(12'h000, 32'd0, 4'hF, err);
        
        apb_write(12'h008, 32'd2, 4'hF, err);
        apb_write(12'h000, 32'd1, 4'hF, err);
        #1; check(pwm_out_o[0] == 1, "T10: Duty 50% phase 0 is high");
        @(posedge pclk); #1; check(pwm_out_o[0] == 1, "T10: Duty 50% phase 1 is high");
        @(posedge pclk); #1; check(pwm_out_o[0] == 0, "T10: Duty 50% phase 2 is low");
        @(posedge pclk); #1; check(pwm_out_o[0] == 0, "T10: Duty 50% phase 3 is low");
        apb_write(12'h000, 32'd0, 4'hF, err);

        apb_write(12'h008, 32'd4, 4'hF, err);
        apb_write(12'h000, 32'd1, 4'hF, err);
        #1; check(pwm_out_o[0] == 1, "T10: Duty 100% phase 0 is high");
        @(posedge pclk); #1; check(pwm_out_o[0] == 1, "T10: Duty 100% phase 1 is high");
        @(posedge pclk); #1; check(pwm_out_o[0] == 1, "T10: Duty 100% phase 2 is high");
        @(posedge pclk); #1; check(pwm_out_o[0] == 1, "T10: Duty 100% phase 3 is high");
        apb_write(12'h000, 32'd0, 4'hF, err);
        
        do_reset();
        
        // T11: PERIOD=1
        apb_write(12'h004, 32'd1, 4'hF, err);
        apb_write(12'h008, 32'd1, 4'hF, err);
        apb_write(12'h000, 32'd1, 4'hF, err);
        #1; check(pwm_out_o[0] == 1, "T11: PERIOD=1 DUTY=1 phase 0 is high");
        @(posedge pclk); #1; check(pwm_out_o[0] == 1, "T11: PERIOD=1 DUTY=1 phase 0 next is high");
        apb_write(12'h000, 32'd0, 4'hF, err);

        do_reset();
        
        // T12, T13: Prescalers
        apb_write(12'h004, 32'd4, 4'hF, err);
        apb_write(12'h008, 32'd1, 4'hF, err);
        apb_write(12'h00C, 32'd1, 4'hF, err); // PRESCALE=1
        apb_write(12'h000, 32'd1, 4'hF, err);
        #1; check(pwm_out_o[0] == 1, "T12: PRESCALE=1 phase 0-0 is high");
        @(posedge pclk); #1; check(pwm_out_o[0] == 1, "T12: PRESCALE=1 phase 0-1 is high");
        @(posedge pclk); #1; check(pwm_out_o[0] == 0, "T12: PRESCALE=1 phase 1-0 is low");
        @(posedge pclk); #1; check(pwm_out_o[0] == 0, "T12: PRESCALE=1 phase 1-1 is low");
        apb_write(12'h000, 32'd0, 4'hF, err);
        
                // T13: PRESCALE=65535 exact timing
        apb_write(12'h004, 32'd2, 4'hF, err);
        apb_write(12'h008, 32'd1, 4'hF, err);
        apb_write(12'h00C, 32'd65535, 4'hF, err); // PRESCALE=65535
        apb_write(12'h000, 32'd1, 4'hF, err);
        #1; check(pwm_out_o[0] == 1, "T13: PRESCALE=65535 phase 0 is high");
        // It stays high for 65536 clocks per phase
        // Let's advance 65535 clocks
        repeat(65535) @(posedge pclk);
        #1; check(pwm_out_o[0] == 1, "T13: PRESCALE=65535 output remains high right before edge");
        @(posedge pclk);
        #1; check(pwm_out_o[0] == 0, "T13: PRESCALE=65535 output goes low exactly at edge");
        apb_write(12'h000, 32'd0, 4'hF, err);

        do_reset();

        // T14: Inverted polarity
        apb_write(12'h004, 32'd4, 4'hF, err);
        apb_write(12'h008, 32'd1, 4'hF, err);
        apb_write(12'h000, 32'd3, 4'hF, err); // EN=1, POL=1
        #1; check(pwm_out_o[0] == 0, "T14: POL=1 Phase 0 is low");
        @(posedge pclk); #1; check(pwm_out_o[0] == 1, "T14: POL=1 Phase 1 is high");
        apb_write(12'h000, 32'd0, 4'hF, err);
        #1; check(pwm_out_o[0] == 0, "T14: POL=1 Disabled is low");

        do_reset();

                // T15: 4 channels concurrent
        apb_write(12'h004, 32'd4, 4'hF, err); apb_write(12'h008, 32'd2, 4'hF, err);
        apb_write(12'h024, 32'd8, 4'hF, err); apb_write(12'h028, 32'd4, 4'hF, err);
        apb_write(12'h044, 32'd2, 4'hF, err); apb_write(12'h048, 32'd1, 4'hF, err);
        apb_write(12'h064, 32'd4, 4'hF, err); apb_write(12'h068, 32'd2, 4'hF, err);
        
        apb_write(12'h000, 32'd1, 4'hF, err); // CH0
        apb_write(12'h020, 32'd1, 4'hF, err); // CH1
        apb_write(12'h040, 32'd1, 4'hF, err); // CH2
        apb_write(12'h060, 32'd3, 4'hF, err); // CH3 (POL=1)
        
        #1; 
        check(pwm_oe_o == 4'b1111, "T15: All 4 channels enabled");
        // CH0 (P=4,D=2), CH1 (P=8,D=4), CH2 (P=2,D=1), CH3 (P=4,D=2, POL=1)
        // Simulate for a few clocks, predicting exact outputs
        // They were enabled sequentially, so phase offsets exist.
        // CH0 started 3 writes ago (so phase 3), CH1 (phase 2), CH2 (phase 1), CH3 (phase 0)
        // Wait, apb_write takes 3 cycles.
        // Let's just do a reset and enable them simultaneously via a broader write? Not possible in APB.
        // We will just read `pwm_out_o` and log it, wait, we must ASSERT exact outputs.
        // Since apb_write takes exactly 3 pclk cycles:
        // CH0 is at phase 9 (which is 9%4 = 1)
        // CH1 is at phase 6 (6%8 = 6)
        // CH2 is at phase 3 (3%2 = 1)
        // CH3 is at phase 0
        // Expected now:
        // CH0: phase 1 < 2 -> 1
        // CH1: phase 6 < 4 -> 0
        // CH2: phase 1 < 1 -> 0
        // CH3: phase 0 < 2 ^ 1 -> 1 ^ 1 = 0
        check(pwm_out_o == 4'b0001, "T15: Exact concurrent outputs correct (cycle 0)");
        @(posedge pclk); #1; // CH0:ph2(0), CH1:ph7(0), CH2:ph0(1), CH3:ph1(0) -> 0100
        check(pwm_out_o == 4'b0100, "T15: Exact concurrent outputs correct (cycle 1)");
        @(posedge pclk); #1; // CH0:ph3(0), CH1:ph0(1), CH2:ph1(0), CH3:ph2(1) -> 1010
        check(pwm_out_o == 4'b1010, "T15: Exact concurrent outputs correct (cycle 2)");

        do_reset();
        
        // T24: Invalid configs
        apb_write(12'h004, 32'd0, 4'hF, err); // PERIOD=0
        apb_write(12'h000, 32'd1, 4'hF, err); // Enable should fail
        check(err == 1, "T24: Enable with PERIOD=0 rejected");

        apb_write(12'h004, 32'd2, 4'hF, err); 
        apb_write(12'h008, 32'd5, 4'hF, err); // DUTY>PERIOD
        apb_write(12'h010, 32'd1, 4'hF, err); // ARM should fail
        check(err == 1, "T24: ARM with DUTY>PERIOD rejected");

        do_reset();

        // T25: Polarity change while running
        apb_write(12'h004, 32'd10, 4'hF, err);
        apb_write(12'h008, 32'd5, 4'hF, err);
        apb_write(12'h000, 32'd1, 4'hF, err); // EN=1, POL=0
        apb_write(12'h000, 32'd3, 4'hF, err); // EN=1, POL=1
        check(err == 1, "T25: Polarity change while running rejected");
        
        
        
        do_reset();

                        // T18-T21: Buffered update pending
        apb_write(12'h004, 32'd10, 4'hF, err);
        apb_write(12'h008, 32'd5, 4'hF, err);
        apb_write(12'h000, 32'd1, 4'hF, err); // Start running with period 10

        apb_write(12'h004, 32'd100, 4'hF, err); // shadow period
        apb_write(12'h010, 32'd1, 4'hF, err); // ARM
        check(err == 0, "T19: ARM accepted");
        apb_write(12'h004, 32'd50, 4'hF, err); // Write while pending
        check(err == 1, "T19: Write while pending rejected");
        
        do_reset();
        
        // T21: ARM on boundary
        apb_write(12'h004, 32'd8, 4'hF, err);
        apb_write(12'h008, 32'd4, 4'hF, err);
        apb_write(12'h000, 32'd1, 4'hF, err); // Start running
        
        repeat(2) @(posedge pclk);
        
        apb_write(12'h004, 32'd4, 4'hF, err); // phase becomes 5
        apb_write(12'h010, 32'd1, 4'hF, err); // ARM completes at phase 0!
        
        // It applies at NEXT boundary.
        apb_read(12'h018, rdata, err); 
        // phase was 0 when apb_read started. Setup cycle -> ph 1. Access cycle -> ph 2. Data sampled.
        check(rdata == 32'd2, "T21: ARM on boundary deferred to next boundary (phase is 2)");
        
        repeat(4) @(posedge pclk); 
        @(posedge pclk); #1; // phase 0 of NEW period
        
        apb_read(12'h018, rdata, err); 
        check(rdata == 32'd2, "T20: New period applied (phase 2)");
        @(posedge pclk); 
        apb_read(12'h018, rdata, err); 
        check(rdata == 32'd2, "T20: Period is indeed 4 (phase 2 again)");
        
        do_reset();
        
        apb_write(12'h004, 32'd4, 4'hF, err);
        apb_write(12'h008, 32'd2, 4'hF, err);
        apb_write(12'h000, 32'd1, 4'hF, err);

        
        // Wait for boundary
        apb_write(12'h100, 32'h1, 4'hF, err); // Enable CH0 IRQ
        while(1) begin
            apb_read(12'h104, rdata, err);
            if (rdata[0]) break;
        end
        
        check(irq_o == 1, "T26: Masked IRQ asserted irq_o");
        
        // T27: W1C
        apb_write(12'h104, 32'hF, 4'hF, err);
        apb_read(12'h104, rdata, err);
        check(rdata[0] == 0, "T27: W1C clears IRQ");
        check(irq_o == 0, "T26: W1C clears irq_o");

        do_reset();
        
        // T28: W1C colliding with boundary
        // Enable with period=8. Wait until phase=7. Then do W1C.
        apb_write(12'h004, 32'd8, 4'hF, err);
        apb_write(12'h008, 32'd1, 4'hF, err);
        apb_write(12'h104, 32'hF, 4'hF, err); // clear any IRQ
        apb_write(12'h000, 32'd1, 4'hF, err); // Phase 0
        
        // apb_write takes 3 cycles. We are at phase 0.
        // Wait until phase 6. Phase is currently 0. Wait 6 cycles.
        repeat(6) @(posedge pclk);
        // Now phase is 6. Start APB write. Setup takes 1 posedge, access takes 1.
        paddr <= 12'h104;
        psel <= 1;
        penable <= 0;
        pwrite <= 1;
        pwdata <= 32'hF;
        pstrb <= 4'hF;
        @(posedge pclk); // Phase 7
        penable <= 1;
        @(posedge pclk); // Wrap occurs HERE! HW SET and W1C collide!
        while (!pready) @(posedge pclk);
        psel <= 0;
        penable <= 0;
        
        apb_read(12'h104, rdata, err);
        check(rdata[0] == 1, "T28: HW SET wins over W1C");

        if (errors > 0) begin
            $display("FAILED with %0d errors out of %0d checks", errors, checks);
            $fatal(1);
        end else begin
            $display("PASSED %0d directed checks successfully", checks);
            $finish;
        end
    end
endmodule
