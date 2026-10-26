`timescale 1ns/1ps

module tb_plic;
    logic clk;
    logic nrst;

    // Interfaces
    bus_protocol_if bus();
    plic_if irq_if();

    // DUT
    plic u_plic (
        .clk(clk),
        .nrst(nrst),
        .bus(bus.peripheral_vital),
        .irq_if(irq_if.plic)
    );

    // Clock gen
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Task: Bus Write
    task bus_write(input logic [31:0] addr, input logic [31:0] data);
        @(posedge clk);
        bus.wen = 1;
        bus.ren = 0;
        bus.addr = addr;
        bus.wdata = data;
        bus.strobe = 4'hF;
        @(posedge clk);
        bus.wen = 0;
    endtask

    // Task: Bus Read
    task bus_read(input logic [31:0] addr, output logic [31:0] data, output logic error);
        @(posedge clk);
        bus.wen = 0;
        bus.ren = 1;
        bus.addr = addr;
        @(posedge clk);
        data = bus.rdata;
        error = bus.error;
        bus.ren = 0;
    endtask

    logic [31:0] rdata;
    logic err;
    int err_cnt = 0;

    initial begin
        // Init
        nrst = 0;
        bus.wen = 0;
        bus.ren = 0;
        bus.addr = 0;
        bus.wdata = 0;
        bus.strobe = 0;
        irq_if.irq_source = '0;

        #20 nrst = 1;

        // T01_RESET: Test PLIC-REQ-008, PLIC-REQ-001
        bus_read(32'h000000, rdata, err); // PRIORITY[0]
        if (rdata !== 0) begin $display("FAIL: PRIORITY[0] != 0"); err_cnt++; end
        
        bus_write(32'h000000, 32'h7); // Try to write PRIORITY[0]
        bus_read(32'h000000, rdata, err);
        if (rdata !== 0) begin $display("FAIL: PRIORITY[0] write not ignored"); err_cnt++; end

        // T02_BASIC_INT: Test PLIC-REQ-002, PLIC-REQ-003, PLIC-REQ-004, PLIC-REQ-005
        bus_write(32'h000004, 32'h7); // PRIORITY[1] = 7
        bus_write(32'h002000, 32'h2); // ENABLE[1] = 1 (bit 1)
        bus_write(32'h200000, 32'h0); // THRESHOLD = 0

        irq_if.irq_source[1] = 1'b1; // Trigger IRQ 1
        @(posedge clk);
        @(posedge clk);
        irq_if.irq_source[1] = 1'b0;
        
        if (irq_if.irq_target !== 1'b1) begin $display("FAIL: irq_target not asserted"); err_cnt++; end

        bus_read(32'h200004, rdata, err); // CLAIM
        if (rdata !== 1) begin $display("FAIL: CLAIM != 1 (got %0d)", rdata); err_cnt++; end
        
        @(posedge clk);
        if (irq_if.irq_target !== 1'b0) begin $display("FAIL: irq_target not deasserted after claim"); err_cnt++; end

        bus_write(32'h200004, 32'h1); // COMPLETE
        
        // T03_PRIORITY_TIE: Test PLIC-REQ-006
        bus_write(32'h000008, 32'h5); // PRIORITY[2] = 5
        bus_write(32'h00000C, 32'h5); // PRIORITY[3] = 5
        bus_write(32'h002000, 32'hC); // ENABLE[2], ENABLE[3]

        irq_if.irq_source[2] = 1;
        irq_if.irq_source[3] = 1;
        @(posedge clk);
        @(posedge clk);
        $display("DBG TIE: prio2=%0d prio3=%0d en2=%0d en3=%0d pend2=%0d pend3=%0d max=%0d",
                 u_plic.priority_q[2], u_plic.priority_q[3], 
                 u_plic.enable_q[2], u_plic.enable_q[3],
                 u_plic.pending_q[2], u_plic.pending_q[3],
                 u_plic.max_id);
        
        bus_read(32'h200004, rdata, err); // CLAIM
        if (rdata !== 2) begin $display("FAIL: Tie-breaker failed, got %0d", rdata); err_cnt++; end
        bus_write(32'h200004, 32'h2); // COMPLETE

        // Claim the other one
        bus_read(32'h200004, rdata, err); // CLAIM
        if (rdata !== 3) begin $display("FAIL: Second pending interrupt claim failed"); err_cnt++; end
        bus_write(32'h200004, 32'h3); // COMPLETE

        // T04_UNMAPPED: Test PLIC-REQ-007
        bus_read(32'h001004, rdata, err); // UNMAPPED
        if (err !== 1'b1) begin $display("FAIL: No error on unmapped read"); err_cnt++; end

        if (err_cnt == 0) $display("PASS");
        else $display("FAIL with %0d errors", err_cnt);
        
        $finish;
    end
endmodule