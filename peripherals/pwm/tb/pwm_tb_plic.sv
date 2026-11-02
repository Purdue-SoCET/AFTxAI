`default_nettype none
`timescale 1ns/1ps

module pwm_tb_plic;

    logic hclk = 0;
    logic pclk = 0;
    logic hresetn = 0;
    logic presetn = 0;

    always #5 hclk = ~hclk;   // 100 MHz AHB/PLIC clock
    always #40 pclk = ~pclk;  // 12.5 MHz APB/PWM clock
    
    apb_if #( .ADDR_WIDTH(32), .DATA_WIDTH(32) ) apb_req (pclk, presetn);
    
    localparam int PWM_CHANNELS = 4;
    logic [PWM_CHANNELS-1:0] pwm_out;
    logic [PWM_CHANNELS-1:0] pwm_oe;
    logic irq_o;
    
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
        .irq_o(irq_o)
    );

    // 2-flop Synchronizer
    logic irq_sync1, irq_sync2;
    always_ff @(posedge hclk or negedge hresetn) begin
        if (!hresetn) begin
            irq_sync1 <= 0;
            irq_sync2 <= 0;
        end else begin
            irq_sync1 <= irq_o;
            irq_sync2 <= irq_sync1;
        end
    end

    // PLIC instance
    bus_protocol_if #( .ADDR_WIDTH(32), .DATA_WIDTH(32) ) plic_bus ();
    plic_if plic_irq ();
    
    assign plic_irq.irq_source = {16'h0, irq_sync2, 14'h0}; // Source 15
    
    plic plic_inst (
        .clk(hclk),
        .nrst(hresetn),
        .bus(plic_bus.peripheral_vital),
        .irq_if(plic_irq.plic)
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

    task plic_write(input logic [31:0] addr, input logic [31:0] data);
        @(posedge hclk);
        plic_bus.addr <= addr;
        plic_bus.wdata <= data;
        plic_bus.wen <= 1'b1;
        plic_bus.ren <= 1'b0;
        @(posedge hclk);
        plic_bus.wen <= 1'b0;
    endtask

    task plic_read(input logic [31:0] addr, output logic [31:0] data);
        @(posedge hclk);
        plic_bus.addr <= addr;
        plic_bus.ren <= 1'b1;
        plic_bus.wen <= 1'b0;
        @(posedge hclk);
        plic_bus.ren <= 1'b0;
        data = plic_bus.rdata;
    endtask

    logic [31:0] rdata;

    initial begin
        $display("Starting PLIC Integration Test...");
        presetn = 0; hresetn = 0;
        apb_req.PSEL = '0; plic_bus.wen = 0; plic_bus.ren = 0;
        #100 presetn = 1; hresetn = 1;
        #100;
        
        // 1. Configure PLIC for Source 15
        plic_write(32'h00_003C, 32'd5); // Priority 5 for source 15
        plic_write(32'h00_2000, 32'h00008000); // Enable source 15
        plic_write(32'h20_0000, 32'd1); // Threshold 1
        
        // 2. Generate PWM IRQ
        apb_write(12'h004, 32'h10); // PERIOD = 16
        apb_write(12'h000, 32'h01); // EN=1
        apb_write(12'h100, 32'h01); // IRQ Enable CH0
        
        // Wait for IRQ
        wait(irq_o);
        check_ok("PWM irq_o asserted", irq_o == 1);
        
        // Wait for sync to PLIC and PLIC target assertion
        wait(plic_irq.irq_target);
        check_ok("PLIC target asserted after sync delay", plic_irq.irq_target == 1);
        
        // 3. Claim the interrupt
        plic_read(32'h20_0004, rdata);
        check_ok("Claim returns source 15", rdata == 15);
        
        // Wait 10 hclk cycles. PLIC target should be deasserted because we claimed it
        repeat(10) @(posedge hclk);
        check_ok("PLIC target deasserted after claim", plic_irq.irq_target == 0);
        
        // 4. Clear PWM-local pending (W1C)
        apb_write(12'h104, 32'h01);
        repeat(10) @(posedge pclk);
        check_ok("PWM irq_o deasserted after W1C", irq_o == 0);
        
        // 5. Complete PLIC
        plic_write(32'h20_0004, 32'd15);
        
        // Wait a few hclks
        repeat(10) @(posedge hclk);
        check_ok("PLIC ready for next", plic_irq.irq_target == 0);
        
        $display("Checks executed: %0d", tested_checks);
        if (failed_checks > 0) begin
            $display("FAILED %0d checks!", failed_checks);
            $fatal(1);
        end else begin
            $display("ALL PLIC Checks PASSED!");
            $finish(0);
        end
    end

endmodule
`default_nettype wire
