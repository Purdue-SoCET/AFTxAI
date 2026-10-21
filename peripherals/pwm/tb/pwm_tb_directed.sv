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
            $error("FAIL: %s", msg);
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

    initial begin
        logic err;
        logic [31:0] rdata;
        presetn = 0;
        psel = 0;
        penable = 0;
        pwrite = 0;
        pstrb = 0;
        pwdata = 0;
        paddr = 0;
        pprot = 0;

        // T01: Reset defaults
        repeat(5) @(posedge pclk);
        presetn = 1;
        repeat(5) @(posedge pclk);
        
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

        // T08-T17: Exact waveforms and edges
        // Set PERIOD=4, DUTY=1, PRESCALE=0
        apb_write(12'h004, 32'd4, 4'hF, err); // PERIOD
        apb_write(12'h008, 32'd1, 4'hF, err); // DUTY
        apb_write(12'h00C, 32'd0, 4'hF, err); // PRESCALE
        
        // ARM while stopped (T22)
        apb_write(12'h010, 32'd1, 4'hF, err); 
        check(err == 0, "T22: ARM while stopped");

        // Enable
        apb_write(12'h000, 32'd1, 4'hF, err); // EN=1
        
        #1;
        check(pwm_out_o[0] == 1, "T09: Phase 0 is high");
        check(pwm_oe_o[0] == 1, "T09: OE is high");
        @(posedge pclk); #1;
        check(pwm_out_o[0] == 0, "T09: Phase 1 is low");
        @(posedge pclk); #1;
        check(pwm_out_o[0] == 0, "T09: Phase 2 is low");
        @(posedge pclk); #1;
        check(pwm_out_o[0] == 0, "T09: Phase 3 is low");
        @(posedge pclk); #1;
        check(pwm_out_o[0] == 1, "T09: Phase 0 next cycle is high");
        
        // T26-T28: IRQ Priority and W1C
        apb_read(12'h104, rdata, err);
        check(rdata[0] == 1, "T26: Boundary IRQ set");

        // Disable
        apb_write(12'h000, 32'd0, 4'hF, err);
        #1;
        check(pwm_out_o[0] == 0 && pwm_oe_o[0] == 0, "T08: EN 1->0 safe off");
        
        // T24: Invalid configs
        apb_write(12'h004, 32'd0, 4'hF, err); // PERIOD=0
        apb_write(12'h000, 32'd1, 4'hF, err); // Enable should fail
        check(err == 1, "T24: Enable with PERIOD=0 rejected");

        apb_write(12'h004, 32'd2, 4'hF, err); 
        apb_write(12'h008, 32'd5, 4'hF, err); // DUTY>PERIOD
        apb_write(12'h010, 32'd1, 4'hF, err); // ARM should fail
        check(err == 1, "T24: ARM with DUTY>PERIOD rejected");
        
        // T25: Polarity change while running
        apb_write(12'h004, 32'd100, 4'hF, err); // LONG period so it doesn't wrap
        apb_write(12'h008, 32'd10, 4'hF, err);
        apb_write(12'h000, 32'd1, 4'hF, err); // EN=1, POL=0
        apb_write(12'h000, 32'd3, 4'hF, err); // EN=1, POL=1
        check(err == 1, "T25: Polarity change while running rejected");

        // T18-T20: Buffered update pending
        apb_write(12'h004, 32'd100, 4'hF, err); // shadow period
        apb_write(12'h010, 32'd1, 4'hF, err); // ARM
        check(err == 0, "T19: ARM accepted");
        apb_write(12'h004, 32'd5, 4'hF, err); // Write while pending
        check(err == 1, "T19: Write while pending rejected");
        
        // Wait for boundary
        while(1) begin
            apb_read(12'h104, rdata, err);
            if (rdata[0]) break;
        end
        
        // Clear pending IRQs
        apb_write(12'h104, 32'hF, 4'hF, err);
        apb_read(12'h104, rdata, err);
        check(rdata == 0, "T27: W1C clears IRQ");
        
        if (errors > 0) begin
            $display("FAILED with %0d errors out of %0d checks", errors, checks);
            $fatal(1);
        end else begin
            $display("PASSED %0d directed checks successfully", checks);
            $finish;
        end
    end
    
    // Debug monitor
    always @(posedge pclk) begin
        if ($time > 6500) begin
            $display("T=%0t paddr=%h psel=%b penable=%b pwrite=%b valid_write=%b ch_phase=%0d boundary=%b irq_pending=%b w1c=%b", 
                     $time, paddr, psel, penable, pwrite, dut.valid_write, dut.ch_phase[0], dut.boundary_events[0], dut.irq_pending[0],
                     (dut.valid_write && dut.is_global_addr && (dut.offset == 12'h104) && dut.pstrb[0] && dut.pwdata[0]));
        end
    end
endmodule
