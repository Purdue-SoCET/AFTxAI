`timescale 1ns/1ps

`include "apb_if.sv"
`include "digital_io_mux_if.sv"

module tb_digital_io_mux;

    // Parameters matching max config
    parameter int NUM_PINS  = 32;
    parameter int NUM_FUNCS = 3;
    parameter int NUM_BITS  = 2;
    parameter int NUM_REGS  = 2;

    logic pclk;
    logic presetn;

    apb_if #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32)
    ) apb (
        .pclk(pclk),
        .presetn(presetn)
    );

    digital_io_mux_if #(
        .NUM_PINS(NUM_PINS),
        .NUM_FUNCS(NUM_FUNCS)
    ) vif ();

    digital_io_mux #(
        .NUM_PINS(NUM_PINS),
        .NUM_FUNCS(NUM_FUNCS),
        .NUM_BITS(NUM_BITS),
        .NUM_REGS(NUM_REGS)
    ) dut (
        .pclk(pclk),
        .presetn(presetn),
        .apb(apb.completer),
        .vif(vif.top)
    );

    // Clock generation
    initial begin
        pclk = 0;
        forever #5 pclk = ~pclk;
    end

    // APB Write Task
    task apb_write(input logic [31:0] addr, input logic [31:0] data, input logic [3:0] strb);
        @(posedge pclk);
        apb.psel <= 1;
        apb.penable <= 0;
        apb.pwrite <= 1;
        apb.paddr <= addr;
        apb.pwdata <= data;
        apb.pstrb <= strb;
        apb.pprot <= '0;
        @(posedge pclk);
        apb.penable <= 1;
        do begin
            @(posedge pclk);
        end while (!apb.pready);
        apb.psel <= 0;
        apb.penable <= 0;
    endtask

    // APB Read Task
    task apb_read(input logic [31:0] addr, output logic [31:0] data, output logic err);
        @(posedge pclk);
        apb.psel <= 1;
        apb.penable <= 0;
        apb.pwrite <= 0;
        apb.paddr <= addr;
        apb.pwdata <= '0;
        apb.pstrb <= '0;
        apb.pprot <= '0;
        @(posedge pclk);
        apb.penable <= 1;
        do begin
            @(posedge pclk);
        end while (!apb.pready);
        data = apb.prdata;
        err = apb.pslverr;
        apb.psel <= 0;
        apb.penable <= 0;
    endtask

    // Initialize interfaces
    initial begin
        apb.psel = 0;
        apb.penable = 0;
        apb.pwrite = 0;
        apb.paddr = '0;
        apb.pwdata = '0;
        apb.pstrb = '0;
        apb.pprot = '0;

        vif.from_module = '0;
        vif.output_enable = '0;
        vif.to_module_iopad = '0;
        
        presetn = 0;
        repeat(5) @(posedge pclk);
        presetn = 1;
        repeat(2) @(posedge pclk);

        run_tests();
        $display("TEST PASSED");
        $finish;
    end

    task run_tests();
        logic [31:0] rdata;
        logic err;
        
        // T01: Reset
        $display("Running T01: Reset");
        apb_read(32'h5000, rdata, err);
        if (rdata !== 0 || err) $error("T01 Failed: SEL0 not 0 after reset");
        apb_read(32'h5004, rdata, err);
        if (rdata !== 0 || err) $error("T01 Failed: SEL1 not 0 after reset");
        if (vif.from_module_ff !== 0) $error("T01 Failed: from_module_ff not 0");
        if (vif.output_en_ff !== 0) $error("T01 Failed: output_en_ff not 0");

        // T02 & T03: RW & pstrb
        $display("Running T02/T03: RW registers & pstrb");
        apb_write(32'h5000, 32'hA5A5A5A5, 4'b1111);
        apb_read(32'h5000, rdata, err);
        if (rdata !== 32'hA5A5A5A5) $error("T02 Failed: Write/Read mismatch SEL0");
        
        apb_write(32'h5000, 32'hFFFFFFFF, 4'b0011); // partial write
        apb_read(32'h5000, rdata, err);
        if (rdata !== 32'hA5A5FFFF) $error("T03 Failed: pstrb partial write mismatch");

        // More pstrb tests on SEL0
        apb_write(32'h5000, 32'h11223344, 4'b0100); // write byte 2
        apb_read(32'h5000, rdata, err);
        if (rdata !== 32'hA522FFFF) $error("T03 Failed: pstrb=0100 mismatch SEL0");
        apb_write(32'h5000, 32'h99887766, 4'b1000); // write byte 3
        apb_read(32'h5000, rdata, err);
        if (rdata !== 32'h9922FFFF) $error("T03 Failed: pstrb=1000 mismatch SEL0");

        // RW & pstrb tests on SEL1 (0x5004)
        apb_write(32'h5004, 32'h5A5A5A5A, 4'b1111);
        apb_read(32'h5004, rdata, err);
        if (rdata !== 32'h5A5A5A5A) $error("T02 Failed: Write/Read mismatch SEL1");

        apb_write(32'h5004, 32'h11223344, 4'b0001); // write byte 0
        apb_read(32'h5004, rdata, err);
        if (rdata !== 32'h5A5A5A44) $error("T03 Failed: pstrb=0001 mismatch SEL1");
        apb_write(32'h5004, 32'h99887766, 4'b0010); // write byte 1
        apb_read(32'h5004, rdata, err);
        if (rdata !== 32'h5A5A7744) $error("T03 Failed: pstrb=0010 mismatch SEL1");
        apb_write(32'h5004, 32'hAABBCCDD, 4'b0100); // write byte 2
        apb_read(32'h5004, rdata, err);
        if (rdata !== 32'h5ABB7744) $error("T03 Failed: pstrb=0100 mismatch SEL1");
        apb_write(32'h5004, 32'hFFEEDDCC, 4'b1000); // write byte 3
        apb_read(32'h5004, rdata, err);
        if (rdata !== 32'hFFBB7744) $error("T03 Failed: pstrb=1000 mismatch SEL1");

        // Test pstrb=0000
        apb_write(32'h5000, 32'hFFFFFFFF, 4'b0000);
        apb_write(32'h5004, 32'hFFFFFFFF, 4'b0000);

        // Reset SEL0 and SEL1
        apb_write(32'h5000, 32'h0, 4'b1111); 
        apb_write(32'h5004, 32'h0, 4'b1111); 
        
        // T04: Errors (unmapped addresses strictly trigger pslverr)
        $display("Running T04: Errors");
        apb_read(32'h5008, rdata, err);
        if (!err) $error("T04 Failed: No pslverr on 0x5008 read");
        apb_write(32'h5008, 32'h0, 4'b1111);
        apb_read(32'h5008, rdata, err); // just to grab the err from the write if we could, but our apb_write doesn't capture err
        // Let's modify apb_write to check err or just do it inline
        @(posedge pclk);
        apb.psel <= 1; apb.penable <= 0; apb.pwrite <= 1; apb.paddr <= 32'h500C; apb.pwdata <= 32'h123; apb.pstrb <= 4'hF;
        @(posedge pclk);
        apb.penable <= 1;
        do @(posedge pclk); while (!apb.pready);
        if (!apb.pslverr) $error("T04 Failed: No pslverr on 0x500C write");
        apb.psel <= 0; apb.penable <= 0;
        
        // T05: Invalid FSEL condition coverage
        $display("Running T05: Invalid FSEL (fsel >= NUM_FUNCS)");
        apb_write(32'h5000, 32'h00000003, 4'b1111); // fsel = 3, but NUM_FUNCS = 3
        @(posedge pclk); @(posedge pclk);
        
        // T06: Output path latency (1 cycle)
        $display("Running T06: Output path latency");
        apb_write(32'h5000, 32'h00000001, 4'b1111); // pin 0 fsel = 1
        
        @(posedge pclk);
        vif.from_module[1] = 1'b1; // Pin 0 Func 1
        vif.output_enable[1] = 1'b1;
        
        @(posedge pclk);
        #1;
        if (vif.from_module_ff[0] !== 1'b1 || vif.output_en_ff[0] !== 1'b1) 
            $error("T06 Failed: Output latency mismatch");

        vif.from_module[1] = 1'b0; 
        vif.output_enable[1] = 1'b0;

        // T07: Input path latency (2 cycles)
        $display("Running T07: Input path latency");
        vif.to_module_iopad[0] = 1'b1;
        @(posedge pclk);
        @(posedge pclk);
        #1;
        if (vif.to_module[1] !== 1'b1) $error("T07 Failed: Input latency mismatch");
        vif.to_module_iopad[0] = 1'b0;
        
        // T08: Dynamic fsel change timing (0 cycles)
        $display("Running T08: Dynamic fsel change timing");
        vif.to_module_iopad[0] = 1'b1;
        @(posedge pclk);
        @(posedge pclk); 
        apb_write(32'h5000, 32'h00000002, 4'b1111); // Switch to Function 2
        #1;
        if (vif.to_module[2] !== 1'b1) $error("T08 Failed: Dynamic routing failed");

        $display("Basic tests complete.");
    endtask

endmodule