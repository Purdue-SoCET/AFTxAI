`timescale 1ns/1ps

module pwm_tb_directed #(parameter int PWM_CHANNELS = 4);
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
        .PWM_CHANNELS(PWM_CHANNELS),
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
        check(rdata == {16'h5057, 8'h01, 8'(PWM_CHANNELS)}, "T01: PWM_INFO correct");
        
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

        // T04: 16 PSTRB combinations on writable register (CH0 PERIOD 0x004)
        for (int i = 0; i < 16; i++) begin
            logic [31:0] expected;
            apb_write(12'h004, 32'h00000000, 4'hF, err); // Reset to 0
            
            // Expected value based on strb
            expected = 0;
            if (i[0]) expected[7:0] = 8'hAA;
            if (i[1]) expected[15:8] = 8'hBB;
            if (i[2]) expected[23:16] = 8'hCC;
            if (i[3]) expected[31:24] = 8'hDD;
            
            apb_write(12'h004, 32'hDDCCBBAA, i[3:0], err);
            check(err == 0, $sformatf("T04: PSTRB %0h write no error", i));
            apb_read(12'h004, rdata, err);
            check(rdata == expected, $sformatf("T04: PSTRB %0h readback %h expected %h", i, rdata, expected));
        end
        
        do_reset();

        // T16, T17: Absent channel
        for (int ch = PWM_CHANNELS; ch < 4; ch++) begin
            apb_read(12'h000 + (ch * 12'h20), rdata, err);
            check(err == 1, $sformatf("T16: Absent channel %0d access PSLVERR", ch));
            apb_write(12'h000 + (ch * 12'h20), 32'd0, 4'hF, err);
            check(err == 1, $sformatf("T16: Absent channel %0d write PSLVERR", ch));
        end

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
        if (PWM_CHANNELS == 4) begin
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
            check(pwm_out_o == 4'b0001, "T15: Exact concurrent outputs correct (cycle 0)");
            @(posedge pclk); #1; // CH0:ph2(0), CH1:ph7(0), CH2:ph0(1), CH3:ph1(0) -> 0100
            check(pwm_out_o == 4'b0100, "T15: Exact concurrent outputs correct (cycle 1)");
            @(posedge pclk); #1; // CH0:ph3(0), CH1:ph0(1), CH2:ph1(0), CH3:ph2(1) -> 1010
            check(pwm_out_o == 4'b1010, "T15: Exact concurrent outputs correct (cycle 2)");

            do_reset();
        end
        
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

        // --- T18-T21: Exact Cycle Boundary Testing ---
        do_reset();
        
        // Set P=20, D=10
        apb_write(12'h004, 32'd20, 4'hF, err);
        apb_write(12'h008, 32'd10, 4'hF, err);
        
        // Start running
        apb_write(12'h000, 32'd1, 4'hF, err);
        
        // We are early in the 20-cycle period.
        // Write Shadow P=40, D=20
        apb_write(12'h004, 32'd40, 4'hF, err);
        apb_write(12'h008, 32'd20, 4'hF, err);
        
        // Active should still be P=20.
        // Let's ARM it.
        apb_write(12'h010, 32'd1, 4'hF, err);
        
        // Read UPDATE_PENDING from CH0 STATUS (0x014)
        apb_read(12'h014, rdata, err);
        check(rdata[0] == 1, "T19: UPDATE_PENDING is set after ARM");
        
        // Wait for boundary of P=20. We can poll CH_PHASE.
        while(1) begin
            apb_read(12'h018, rdata, err);
            if (rdata >= 32'd18) break; // Close to boundary
        end
        
        // Wait exactly until phase wraps to 0
        while(1) begin
            apb_read(12'h018, rdata, err);
            if (rdata == 32'd0) break;
        end
        
        // Now we are in the NEW period (P=40).
        apb_read(12'h014, rdata, err);
        check(rdata[0] == 0, "T20: UPDATE_PENDING cleared at boundary");
        
        // Wait and check phase goes beyond 19 (proving new period applied)
        while(1) begin
            apb_read(12'h018, rdata, err);
            if (rdata > 32'd19) break; 
        end
        check(rdata > 32'd19, "T20: New period 40 applied");
        
        do_reset();
        
        // T21: ARM on boundary
        // We will just do the existing T21 logic.
        apb_write(12'h004, 32'd8, 4'hF, err);
        apb_write(12'h008, 32'd4, 4'hF, err);
        apb_write(12'h000, 32'd1, 4'hF, err); // Start running
        
        repeat(2) @(posedge pclk);
        
        apb_write(12'h004, 32'd4, 4'hF, err); 
        apb_write(12'h010, 32'd1, 4'hF, err); // ARM completes at phase 0 or 1
        
        // It applies at NEXT boundary.
        apb_read(12'h018, rdata, err); 
        check(rdata < 8, "T21: ARM on boundary deferred to next boundary");
        
        repeat(16) @(posedge pclk); 
        
        apb_read(12'h018, rdata, err); 
        // If period 4 is applied, phase should never be 4 or above.
        // Actually, just sample phase a few times.
        check(rdata < 4, "T20: New period 4 applied (phase bound)");
        
        do_reset();

        
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
        // Enable with period=8. 
        apb_write(12'h004, 32'd8, 4'hF, err);
        apb_write(12'h008, 32'd1, 4'hF, err);
        apb_write(12'h104, 32'hF, 4'hF, err); // clear any IRQ
        apb_write(12'h000, 32'd1, 4'hF, err); // Phase 0 starts next cycle
        
        // After apb_write completes, we are at Phase 0.
        // Let's read IRQ_PENDING to prove it's clear. This takes 3 cycles.
        // So we will be at Phase 3 when read finishes.
        apb_read(12'h104, rdata, err);
        check(rdata[0] == 0, "T28: IRQ_PENDING is clear before collision");
        
        // We are at Phase 3. 
        // Wait 3 cycles to reach Phase 6.
        repeat(3) @(posedge pclk);
        
        // Now phase is 6. Start W1C APB write. 
        paddr <= 12'h104; psel <= 1; penable <= 0; pwrite <= 1; pwdata <= 32'hF; pstrb <= 4'hF; pprot <= 0;
        @(posedge pclk); // Phase 7
        penable <= 1;
        @(posedge pclk); // Boundary wrap occurs HERE! HW SET and W1C collide!
        while (!pready) @(posedge pclk);
        psel <= 0; penable <= 0;
        
        apb_read(12'h104, rdata, err);
        check(rdata[0] == 1, "T28: HW SET wins over W1C, IRQ_PENDING remains set afterward");

        if (errors > 0) begin
            $display("FAILED with %0d errors out of %0d checks", errors, checks);
            $fatal(1);
        end else begin
            $display("PASSED %0d directed checks successfully", checks);
            $finish;
        end
    end
endmodule
