`default_nettype none
`timescale 1ns/1ps

module pwm_tb_apb_integration;

    logic pclk = 0;
    logic presetn = 0;
    
    always #40 pclk = ~pclk; // 12.5 MHz APB clock (80ns period)
    
    // Instantiate APB buses
    apb_if #( .ADDR_WIDTH(32), .DATA_WIDTH(32) ) apb_req (pclk, presetn);
    apb_if #( .ADDR_WIDTH(32), .DATA_WIDTH(32) ) apb_comp [2] (pclk, presetn);
    
    // PWM Config
    localparam int PWM_CHANNELS = 4;
    logic [PWM_CHANNELS-1:0] pwm_out;
    logic [PWM_CHANNELS-1:0] pwm_oe;
    logic irq;
    
    // Interconnect configuration:
    // Completer 0: PWM (Base 0x0000_1000)
    // Completer 1: Dummy (Base 0x0000_2000)
    localparam logic [31:0] PWM_BASE   = 32'h0000_1000;
    localparam logic [31:0] DUMMY_BASE = 32'h0000_2000;
    
    logic [31:0] apb_map [2];
    assign apb_map[0] = PWM_BASE;
    assign apb_map[1] = DUMMY_BASE;
    
    apb_interconnect #(
        .NCOMPLETERS(2),
        .COMPLETER_ADDR_BITS(12), // 4KB granularity for early test
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .APB_MAP('{PWM_BASE, DUMMY_BASE})
    ) ic (
        .requester(apb_req.completer),
        .completers(apb_comp)
    );
    
    // Completer 0: PWM wrapper
    pwm_apb_wrapper #(
        .PWM_CHANNELS(PWM_CHANNELS),
        .BASE_ADDR(PWM_BASE)
    ) dut (
        .pclk      (pclk),
        .presetn   (presetn),
        .apb(apb_comp[0].completer),
        .pwm_out_o(pwm_out),
        .pwm_oe_o(pwm_oe),
        .irq_o(irq)
    );
    
    // Completer 1: Dummy to test isolation
    assign apb_comp[1].pready = 1'b1;
    assign apb_comp[1].prdata = 32'hDEADBEEF;
    assign apb_comp[1].pslverr = 1'b0;

    int tested_checks = 0;
    int failed_checks = 0;

    task apb_write(input logic [31:0] addr, input logic [31:0] data, input logic [3:0] strb = 4'hF, output logic slverr);
        @(posedge pclk);
        apb_req.paddr <= addr;
        apb_req.pwrite <= 1'b1;
        apb_req.psel <= 1'b1;
        apb_req.pwdata <= data;
        apb_req.pstrb <= strb;
        apb_req.penable <= 1'b0;
        @(posedge pclk);
        apb_req.penable <= 1'b1;
        do begin
            @(posedge pclk);
        end while (!apb_req.pready);
        slverr = apb_req.pslverr;
        apb_req.psel <= 1'b0;
        apb_req.penable <= 1'b0;
        apb_req.pstrb <= 4'h0;
    endtask

    task apb_read(input logic [31:0] addr, output logic [31:0] data, output logic slverr);
        @(posedge pclk);
        apb_req.paddr <= addr;
        apb_req.pwrite <= 1'b0;
        apb_req.psel <= 1'b1;
        apb_req.pwdata <= '0;
        apb_req.pstrb <= 4'h0;
        apb_req.penable <= 1'b0;
        @(posedge pclk);
        apb_req.penable <= 1'b1;
        do begin
            @(posedge pclk);
        end while (!apb_req.pready);
        data = apb_req.prdata;
        slverr = apb_req.pslverr;
        apb_req.psel <= 1'b0;
        apb_req.penable <= 1'b0;
    endtask

    task check_ok(input string msg, input logic condition);
        tested_checks++;
        if (!condition) begin
            $display("[FAIL] %s", msg);
            failed_checks++;
        end else begin
            $display("[PASS] %s", msg);
        end
    endtask

    logic [31:0] rdata;
    logic err;

    initial begin
        $display("Starting APB Integration Test...");
        
        apb_req.paddr = '0;
        apb_req.pprot = '0;
        apb_req.psel = '0;
        apb_req.penable = '0;
        apb_req.pwrite = '0;
        apb_req.pwdata = '0;
        apb_req.pstrb = '0;

        presetn = 0;
        #100 presetn = 1;
        #100;
        
        // 1. PWM_INFO readback at PWM base + 0x108
        apb_read(PWM_BASE + 'h108, rdata, err);
        check_ok("PWM_INFO readback", !err && rdata == {16'h5057, 8'h01, 8'd4});
        
        // 2 & 3. Channel access and stride
        apb_write(PWM_BASE + 'h04, 32'h100, 4'hF, err); // CH0 PERIOD
        check_ok("CH0 write period OK", !err);
        apb_read(PWM_BASE + 'h04, rdata, err);
        check_ok("CH0 read period", !err && rdata == 32'h100);

        apb_write(PWM_BASE + 'h24, 32'h200, 4'hF, err); // CH1 PERIOD
        check_ok("CH1 write period OK", !err);
        apb_read(PWM_BASE + 'h24, rdata, err);
        check_ok("CH1 read period", !err && rdata == 32'h200);

        // 4. IRQ_ENABLE and IRQ_PENDING
        apb_write(PWM_BASE + 'h100, 32'hF, 4'hF, err);
        check_ok("IRQ_ENABLE write OK", !err);
        apb_read(PWM_BASE + 'h100, rdata, err);
        check_ok("IRQ_ENABLE read OK", !err && rdata == 32'hF);

        // 5. Correct PSTRB behavior
        apb_write(PWM_BASE + 'h44, 32'hAABBCCDD, 4'h2, err); // Write only byte 1 of CH2 PERIOD
        apb_read(PWM_BASE + 'h44, rdata, err);
        check_ok("PSTRB behavior", !err && (rdata == 32'h0000CC01));

        // 6. Zero-strobe legal no-op
        apb_write(PWM_BASE + 'h44, 32'h11223344, 4'h0, err);
        apb_read(PWM_BASE + 'h44, rdata, err);
        check_ok("Zero-strobe no-op", !err && (rdata == 32'h0000CC01));

        // 7. Misaligned access error
        apb_read(PWM_BASE + 'h01, rdata, err);
        check_ok("Misaligned access -> error", err === 1'b1);

        // 8. Reserved offset error
        apb_read(PWM_BASE + 'h1C, rdata, err);
        check_ok("Reserved offset -> error", err === 1'b1);

        // 9. RO write and WO read error
        apb_read(PWM_BASE + 'h10, rdata, err);
        check_ok("WO read -> error", err === 1'b1);
        apb_write(PWM_BASE + 'h14, 32'h0, 4'hF, err);
        check_ok("RO write -> error", err === 1'b1);

        // 10. Out-of-window address error
        apb_read(PWM_BASE + 'hABC, rdata, err);
        check_ok("Out of implemented window -> error", err === 1'b1);

        // 11. No high-address aliasing (Test wrapper's valid_addr check)
        apb_read(PWM_BASE + 'hF000, rdata, err);
        check_ok("Aliasing to F000 blocked", err === 1'b1); // F000 is 1000's higher alias if bits 12+ ignored

        // 12 & 13. Outside access (unmapped) -> interconnect gives PSLVERR
        apb_read(32'h0000_A000, rdata, err);
        check_ok("Unmapped address -> PSLVERR", err === 1'b1 && rdata == 0); // Assuming interconnect sends 0 for unmapped

        // 18. Isolation
        apb_read(DUMMY_BASE, rdata, err);
        check_ok("Dummy read", !err && rdata == 32'hDEADBEEF);
        
        $display("Checks executed: %0d", tested_checks);
        if (failed_checks > 0) begin
            $display("FAILED %0d checks!", failed_checks);
            $fatal(1);
        end else begin
            $display("ALL APB Checks PASSED!");
            $finish(0);
        end
    end

endmodule
`default_nettype wire
