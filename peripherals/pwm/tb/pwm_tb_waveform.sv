`default_nettype none
`timescale 1ns/1ps

module pwm_tb_waveform;

    logic pclk = 0;
    logic presetn = 0;
    
    always #40 pclk = ~pclk; // 12.5 MHz APB clock
    
    apb_if #( .ADDR_WIDTH(32), .DATA_WIDTH(32) ) apb_req (pclk, presetn);
    
    localparam int PWM_CHANNELS = 4;
    logic [PWM_CHANNELS-1:0] pwm_out;
    logic [PWM_CHANNELS-1:0] pwm_oe;
    logic irq;
    
    pwm_core #(
        .PWM_CHANNELS(PWM_CHANNELS),
        .ADDR_WIDTH(12),
        .DATA_WIDTH(32)
    ) dut (
        .pclk(pclk),
        .presetn(presetn),
        .paddr(apb_req.PADDR[11:0]),
        .psel(apb_req.PSEL),
        .penable(apb_req.PENABLE),
        .pwrite(apb_req.PWRITE),
        .pwdata(apb_req.PWDATA),
        .pstrb(apb_req.PSTRB),
        .pprot(apb_req.PPROT),
        .prdata(apb_req.PRDATA),
        .pready(apb_req.PREADY),
        .pslverr(apb_req.PSLVERR),
        .pwm_out_o(pwm_out),
        .pwm_oe_o(pwm_oe),
        .irq_o(irq)
    );

    int tested_checks = 0;
    int failed_checks = 0;
    
    task check_ok(input string msg, input logic condition);
        tested_checks++;
        if (!condition) begin
            $display("[FAIL] %s", msg);
            failed_checks++;
        end else begin
            $display("[PASS] %s", msg);
        end
    endtask

    task apb_write(input logic [11:0] addr, input logic [31:0] data, input logic [3:0] strb = 4'hF);
        @(posedge pclk);
        apb_req.PADDR <= {20'h0, addr};
        apb_req.PWRITE <= 1'b1;
        apb_req.PSEL <= 1'b1;
        apb_req.PWDATA <= data;
        apb_req.PSTRB <= strb;
        apb_req.PENABLE <= 1'b0;
        @(posedge pclk);
        apb_req.PENABLE <= 1'b1;
        do begin
            @(posedge pclk);
        end while (!apb_req.PREADY);
        apb_req.PSEL <= 1'b0;
        apb_req.PENABLE <= 1'b0;
        apb_req.PSTRB <= 4'h0;
    endtask

    task apb_read(input logic [11:0] addr, output logic [31:0] data);
        @(posedge pclk);
        apb_req.PADDR <= {20'h0, addr};
        apb_req.PWRITE <= 1'b0;
        apb_req.PSEL <= 1'b1;
        apb_req.PWDATA <= '0;
        apb_req.PSTRB <= 4'h0;
        apb_req.PENABLE <= 1'b0;
        @(posedge pclk);
        apb_req.PENABLE <= 1'b1;
        do begin
            @(posedge pclk);
        end while (!apb_req.PREADY);
        data = apb_req.PRDATA;
        apb_req.PSEL <= 1'b0;
        apb_req.PENABLE <= 1'b0;
    endtask

    logic [31:0] rdata;

    initial begin
        $display("Starting PWM Waveform & Buffered Update Test...");
        presetn = 0;
        apb_req.PADDR = '0;
        apb_req.PWRITE = '0;
        apb_req.PSEL = '0;
        apb_req.PWDATA = '0;
        apb_req.PSTRB = '0;
        apb_req.PENABLE = '0;
        apb_req.PPROT = '0;
        #100 presetn = 1;
        #100;
        
        // 1. T22: ARM while disabled
        // Configure CH0, but do NOT enable
        apb_write(12'h004, 32'h10); // PERIOD = 16
        apb_write(12'h008, 32'h08); // DUTY = 8
        apb_write(12'h00C, 32'h00); // PRESCALE = 0
        
        // ARM it while disabled
        apb_write(12'h010, 32'h01); // CH_UPDATE
        
        // Check pending bit
        apb_read(12'h014, rdata);
        check_ok("ARM while disabled -> pending=0 (cleared instantly or bypassed)", rdata[0] == 0);
        
        // Ensure out/oe remain low
        #500;
        check_ok("Out/OE remain low when disabled", pwm_out[0] == 0 && pwm_oe[0] == 0);
        
        // Enable
        apb_write(12'h000, 32'h01); // EN=1, POL=0
        
        // Wait 4 cycles
        repeat(4) @(posedge pclk);
        check_ok("Out/OE active after enable", pwm_oe[0] == 1 && pwm_out[0] == 1);
        
        // 2. Buffered update atomicity
        // Write new timing values
        apb_write(12'h004, 32'h20); // PERIOD = 32
        apb_write(12'h008, 32'h10); // DUTY = 16
        
        // Read back shadow
        apb_read(12'h004, rdata);
        check_ok("Shadow PERIOD is 32", rdata == 32'h20);
        
        // Wait a few cycles, active waveform should still be 16 period
        repeat(5) @(posedge pclk);
        // ARM update
        apb_write(12'h010, 32'h01);
        apb_read(12'h014, rdata);
        check_ok("Update pending is 1", rdata[0] == 1);
        
        // Wait until it drops
        fork
            begin
                int cycles = 0;
                while (rdata[0] == 1 && cycles < 40) begin
                    @(posedge pclk);
                    apb_read(12'h014, rdata);
                    cycles++;
                end
                check_ok("Update pending cleared at boundary", rdata[0] == 0);
            end
            begin
                // Monitor waveform for continuous operation
                #1000;
            end
        join_any
        
        // 3. Interrupt behavior & W1C vs HW SET
        // Enable IRQ for CH0
        apb_write(12'h100, 32'h01);
        
        // Wait for boundary event to set pending
        repeat(35) @(posedge pclk);
        apb_read(12'h104, rdata);
        check_ok("IRQ pending set for CH0", rdata[0] == 1);
        check_ok("irq_o asserted", irq == 1);
        
        // W1C
        apb_write(12'h104, 32'h01);
        apb_read(12'h104, rdata);
        check_ok("IRQ pending cleared by W1C", rdata[0] == 0);
        check_ok("irq_o deasserted", irq == 0);
        
        $display("Checks executed: %0d", tested_checks);
        if (failed_checks > 0) begin
            $display("FAILED %0d checks!", failed_checks);
            $fatal(1);
        end else begin
            $display("ALL Waveform Checks PASSED!");
            $finish(0);
        end
    end

endmodule
`default_nettype wire
