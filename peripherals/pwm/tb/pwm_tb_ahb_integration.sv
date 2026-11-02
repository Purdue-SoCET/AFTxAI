`default_nettype none
`timescale 1ns/1ps

module pwm_tb_ahb_integration;

    logic hclk = 0;
    logic pclk = 0;
    logic hresetn = 0;
    logic presetn = 0;

    always #5 hclk = ~hclk;   // 100 MHz AHB clock
    always #40 pclk = ~pclk;  // 12.5 MHz APB clock (aligned but asynchronous setup possible)
    
    ahb_if #( .ADDR_WIDTH(32), .DATA_WIDTH(32) ) ahb_req (hclk, hresetn);
    apb_if #( .ADDR_WIDTH(32), .DATA_WIDTH(32) ) apb_req_bus (pclk, presetn);
    apb_if #( .ADDR_WIDTH(32), .DATA_WIDTH(32) ) apb_comp [2] (pclk, presetn);
    
    assign ahb_req.HREADY = ahb_req.HREADYOUT;
    
    localparam int PWM_CHANNELS = 4;
    logic [PWM_CHANNELS-1:0] pwm_out;
    logic [PWM_CHANNELS-1:0] pwm_oe;
    logic irq;
    
    localparam logic [31:0] BRIDGE_BASE = 32'h8000_0000;
    localparam logic [31:0] PWM_ABS     = 32'h8000_1000;
    localparam logic [31:0] DUMMY_ABS   = 32'h8000_2000;
    
    localparam logic [31:0] PWM_REL     = PWM_ABS - BRIDGE_BASE;
    localparam logic [31:0] DUMMY_REL   = DUMMY_ABS - BRIDGE_BASE;

    ahb2apb #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .BASE_ADDR(BRIDGE_BASE),
        .FIFO_DEPTH(16),
        .NWORDS(4096) // 16KB Window
    ) bridge (
        .ahbif(ahb_req.subordinate),
        .apbif(apb_req_bus.requester)
    );
    
    apb_interconnect #(
        .NCOMPLETERS(2),
        .COMPLETER_ADDR_BITS(12),
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .APB_MAP('{PWM_REL, DUMMY_REL})
    ) ic (
        .requester(apb_req_bus.completer),
        .completers(apb_comp)
    );
    
    pwm_apb_wrapper #(
        .PWM_CHANNELS(PWM_CHANNELS),
        .BASE_ADDR(PWM_REL)
    ) dut (
        .apb(apb_comp[0].completer),
        .pwm_out_o(pwm_out),
        .pwm_oe_o(pwm_oe),
        .irq_o(irq)
    );

    assign apb_comp[1].PREADY = 1'b1;
    assign apb_comp[1].PRDATA = 32'hDEADBEEF;
    assign apb_comp[1].PSLVERR = 1'b0;

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

    task ahb_write(input logic [31:0] addr, input logic [31:0] data, input logic [3:0] strb = 4'hF, output logic hresp);
        // Address phase
        @(posedge hclk);
        ahb_req.HADDR <= addr;
        ahb_req.HWRITE <= 1'b1;
        ahb_req.HSEL <= 1'b1;
        ahb_req.HTRANS <= 2'b10; // NONSEQ
        ahb_req.HSIZE <= 3'b010; // WORD
        ahb_req.HWSTRB <= strb;
        
        // Wait for address phase to be accepted
        do begin
            @(posedge hclk);
        end while (!ahb_req.HREADY);
        
        // Data phase
        ahb_req.HADDR <= '0;
        ahb_req.HWRITE <= 1'b0;
        ahb_req.HSEL <= 1'b0;
        ahb_req.HTRANS <= 2'b00; // IDLE
        ahb_req.HWDATA <= data;
        ahb_req.HWSTRB <= 4'h0;
        
        do begin
            @(posedge hclk);
        end while (!ahb_req.HREADY);
        hresp = ahb_req.HRESP;
    endtask

    task ahb_read(input logic [31:0] addr, output logic [31:0] data, output logic hresp);
        // Address phase
        @(posedge hclk);
        ahb_req.HADDR <= addr;
        ahb_req.HWRITE <= 1'b0;
        ahb_req.HSEL <= 1'b1;
        ahb_req.HTRANS <= 2'b10; // NONSEQ
        ahb_req.HSIZE <= 3'b010; // WORD
        ahb_req.HWSTRB <= 4'h0;
        
        // Wait for address phase
        do begin
            @(posedge hclk);
        end while (!ahb_req.HREADY);
        
        // Data phase
        ahb_req.HADDR <= '0;
        ahb_req.HSEL <= 1'b0;
        ahb_req.HTRANS <= 2'b00; // IDLE
        ahb_req.HWSTRB <= 4'h0;
        
        do begin
            @(posedge hclk);
        end while (!ahb_req.HREADY);
        
        data = ahb_req.HRDATA;
        hresp = ahb_req.HRESP;
        $display("AHB Read: Addr=%h, Data=%h, HRESP=%b", addr, data, hresp);
    endtask

    logic [31:0] rdata;
    logic err;

    initial begin
        $display("Starting AHB->APB Integration Test...");
        hresetn = 0; presetn = 0;
        
        ahb_req.HADDR = '0;
        ahb_req.HWRITE = '0;
        ahb_req.HSEL = '0;
        ahb_req.HTRANS = '0;
        ahb_req.HSIZE = '0;
        ahb_req.HWSTRB = '0;
        ahb_req.HWDATA = '0;

        #100;
        hresetn = 1; presetn = 1;
        #100;
        
        // 1. Write PWM Channel 0 at absolute address
        ahb_write(PWM_ABS + 'h04, 32'h000000A0, 4'hF, err);
        check_ok("AHB write CH0 PERIOD", !err);
        
        ahb_read(PWM_ABS + 'h04, rdata, err);
        check_ok("AHB read CH0 PERIOD", !err && rdata == 32'h000000A0);
        
        // 2. Write PWM Channel 3 at correct absolute offset
        ahb_write(PWM_ABS + 'h64, 32'h000000B0, 4'hF, err);
        check_ok("AHB write CH3 PERIOD", !err);
        ahb_read(PWM_ABS + 'h64, rdata, err);
        check_ok("AHB read CH3 PERIOD", !err && rdata == 32'h000000B0);
        
        // 3. Global IRQ registers
        ahb_write(PWM_ABS + 'h100, 32'h0000000A, 4'hF, err);
        check_ok("AHB write IRQ_ENABLE", !err);
        ahb_read(PWM_ABS + 'h100, rdata, err);
        check_ok("AHB read IRQ_ENABLE", !err && rdata == 32'h0000000A);
        
        // 4. Invalid access -> HRESP error
        ahb_read(PWM_ABS + 'h1C, rdata, err);
        check_ok("AHB read reserved -> ERROR", err === 1'b1);
        
        // 5. APB PSTRB retains AHB byte strobes
        ahb_write(PWM_ABS + 'h04, 32'hDDCCBBAA, 4'h2, err); // write byte 1
        ahb_read(PWM_ABS + 'h04, rdata, err);
        // previous was 000000A0. We write byte 1 to BB. So 0000BBA0
        check_ok("AHB byte strobe retained", !err && rdata == 32'h0000BBA0);
        
        // 6. Test outside the bridge window
        ahb_read(32'h9000_0000, rdata, err);
        check_ok("AHB outside bridge window -> ERROR", err === 1'b1);
        
        // 7. Verify continuous waveform (starts tracking PWM output during unrelated traffic)
        // Enable CH0 with period 10, duty 5
        ahb_write(PWM_ABS + 'h04, 32'h0000000A, 4'hF, err);
        ahb_write(PWM_ABS + 'h08, 32'h00000005, 4'hF, err);
        ahb_write(PWM_ABS + 'h00, 32'h00000001, 4'hF, err);
        
        begin
            int toggle_count = 0;
            int dummy_read_done = 0;
            int waveform_errors = 0;
            
            fork
                begin
                    // align to falling edge then rising edge to find phase 0
                    wait (pwm_out[0] == 0);
                    wait (pwm_out[0] == 1);
                    @(posedge pclk); // move past the edge to phase 1
                    
                    begin
                        int phase = 1;
                        while (!dummy_read_done) begin
                            if (phase < 5) begin
                                if (pwm_out[0] !== 1) begin
                                    waveform_errors++;
                                end
                            end else begin
                                if (pwm_out[0] !== 0) begin
                                    waveform_errors++;
                                end
                            end
                            if (pwm_oe[0] !== 1) waveform_errors++;
                            
                            phase = (phase + 1) % 10;
                            if (phase == 0) toggle_count++;
                            @(posedge pclk);
                            #1;
                        end
                    end
                end
                begin
                    for (int i=0; i<10; i++) begin
                        ahb_read(DUMMY_ABS, rdata, err);
                    end
                    dummy_read_done = 1;
                end
            join
            
            check_ok("Waveform continues during dummy reads", toggle_count > 0 && waveform_errors == 0);
        end
        
        $display("Checks executed: %0d", tested_checks);
        if (failed_checks > 0) begin
            $display("FAILED %0d checks!", failed_checks);
            $fatal(1);
        end else begin
            $display("ALL AHB Checks PASSED!");
            $finish(0);
        end
    end

endmodule
`default_nettype wire
