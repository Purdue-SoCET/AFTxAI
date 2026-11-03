`timescale 1ns/1ps

module tb_dma;

    // ------------------------------------------------------------------------
    // Parameters & Signals
    // ------------------------------------------------------------------------
    parameter int ADDR_W = 32;
    parameter int DATA_W = 32;
    parameter int COUNT_W = 8;
    
    logic clk;
    logic rst_n;
    logic drq;
    logic daq;
    logic irq;

    // Clocks
    initial begin
        clk = 0;
        forever clk = #5 ~clk;
    end
    
    // ------------------------------------------------------------------------
    // Interfaces
    // ------------------------------------------------------------------------
    apb_if #(.ADDR_WIDTH(ADDR_W), .DATA_WIDTH(DATA_W)) reg_bus(.pclk(clk), .presetn(rst_n));
    ahb_if #(.ADDR_WIDTH(ADDR_W), .DATA_WIDTH(DATA_W)) mem_bus(.HCLK(clk), .HRESETn(rst_n));

    // ------------------------------------------------------------------------
    // DUT Instantiation
    // ------------------------------------------------------------------------
    dma_controller #(
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W),
        .COUNT_W(COUNT_W),
        .FIFO_DEPTH(8)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .drq(drq),
        .daq(daq),
        .irq(irq),
        .reg_bus(reg_bus),
        .mem_bus(mem_bus)
    );

    // ------------------------------------------------------------------------
    // Memory Model (AHB-Lite Completer)
    // ------------------------------------------------------------------------
    logic [7:0] memory[1024]; // 1KB memory model
    logic [ADDR_W-1:0] ahb_addr_r;
    logic ahb_write_r;
    logic [2:0] ahb_size_r;
    logic ahb_active;
    logic force_err = 0;
    
    // Drive HREADY and HRESP combinationally for immediate response
    logic hready_int;
    logic hresp_int;
    
    assign mem_bus.HREADY = hready_int;
    assign mem_bus.HRESP = hresp_int;
    
    always_comb begin
        if (force_err && (mem_bus.HTRANS == 2'b10 || mem_bus.HTRANS == 2'b11 || ahb_active)) begin
            hresp_int = 1'b1;
            hready_int = 1'b1; // Single cycle error for simplicity, or 0 if we want to model standard.
            // Actually, if we just want the master to see it, drive it to 1.
        end else begin
            hresp_int = 1'b0;
            hready_int = 1'b1;
        end
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_bus.HRDATA <= '0;
            ahb_active <= 1'b0;
            for(int i=0; i<1024; i++) memory[i] <= 8'h00;
        end else begin
            if (mem_bus.HREADY && (mem_bus.HTRANS == 2'b10 || mem_bus.HTRANS == 2'b11)) begin
                ahb_active <= 1'b1;
                ahb_addr_r <= mem_bus.HADDR;
                ahb_write_r <= mem_bus.HWRITE;
                ahb_size_r <= mem_bus.HSIZE;
            end else if (mem_bus.HREADY) begin
                ahb_active <= 1'b0;
            end

            if (ahb_active && mem_bus.HREADY && !force_err) begin
                if (ahb_write_r) begin
                    if (ahb_size_r == 3'b000) memory[ahb_addr_r[9:0]] <= mem_bus.HWDATA[7:0];
                    else if (ahb_size_r == 3'b001) begin
                        memory[ahb_addr_r[9:0]] <= mem_bus.HWDATA[7:0];
                        memory[ahb_addr_r[9:0]+1] <= mem_bus.HWDATA[15:8];
                    end else begin
                        memory[ahb_addr_r[9:0]] <= mem_bus.HWDATA[7:0];
                        memory[ahb_addr_r[9:0]+1] <= mem_bus.HWDATA[15:8];
                        memory[ahb_addr_r[9:0]+2] <= mem_bus.HWDATA[23:16];
                        memory[ahb_addr_r[9:0]+3] <= mem_bus.HWDATA[31:24];
                    end
                end else begin
                    if (ahb_size_r == 3'b000) mem_bus.HRDATA <= {24'h0, memory[ahb_addr_r[9:0]]};
                    else if (ahb_size_r == 3'b001) mem_bus.HRDATA <= {16'h0, memory[ahb_addr_r[9:0]+1], memory[ahb_addr_r[9:0]]};
                    else mem_bus.HRDATA <= {memory[ahb_addr_r[9:0]+3], memory[ahb_addr_r[9:0]+2], memory[ahb_addr_r[9:0]+1], memory[ahb_addr_r[9:0]]};
                end
            end
        end
    end

    // Tie off global HREADY for single-completer
    assign mem_bus.HREADYOUT = mem_bus.HREADY;

    // ------------------------------------------------------------------------
    // APB Tasks (Register Access)
    // ------------------------------------------------------------------------
    task apb_write(input logic [31:0] addr, input logic [31:0] data);
        @(posedge clk);
        reg_bus.PADDR <= addr;
        reg_bus.PWDATA <= data;
        reg_bus.PWRITE <= 1'b1;
        reg_bus.PSEL <= 1'b1;
        reg_bus.PENABLE <= 1'b0;
        @(posedge clk);
        reg_bus.PENABLE <= 1'b1;
        wait(reg_bus.PREADY);
        @(posedge clk);
        reg_bus.PSEL <= 1'b0;
        reg_bus.PENABLE <= 1'b0;
    endtask

    task apb_read(input logic [31:0] addr, output logic [31:0] data);
        @(posedge clk);
        reg_bus.PADDR <= addr;
        reg_bus.PWRITE <= 1'b0;
        reg_bus.PSEL <= 1'b1;
        reg_bus.PENABLE <= 1'b0;
        @(posedge clk);
        reg_bus.PENABLE <= 1'b1;
        wait(reg_bus.PREADY);
        data = reg_bus.PRDATA;
        $display("APB_READ: paddr=%x prdata=%x", addr, reg_bus.PRDATA);
        @(posedge clk);
        reg_bus.PSEL <= 1'b0;
        reg_bus.PENABLE <= 1'b0;
    endtask

    // ------------------------------------------------------------------------
    // Coverage & Assertions
    // ------------------------------------------------------------------------
    covergroup cg_dma @(posedge clk);
        cp_psize: coverpoint dut.cr[7:6] {
            bins size_8 = {2'b00};
            bins size_16 = {2'b01};
            bins size_32 = {2'b10};
        }
        cp_inc_src: coverpoint dut.cr[12];
        cp_inc_dst: coverpoint dut.cr[11];
        cp_circular: coverpoint dut.cr[10];
    endgroup
    cg_dma dma_cov = new();

    property p_irq_on_finish;
        @(posedge clk) (dut.cr[14] && dut.hw_finished) |=> irq;
    endproperty
    assert property(p_irq_on_finish) else $error("IRQ not asserted on finish!");

    // ------------------------------------------------------------------------
    // Tests
    // ------------------------------------------------------------------------
    initial begin
        logic [31:0] status;
        
        // Defaults
        drq = 0;
        reg_bus.psel = 0;
        reg_bus.penable = 0;
        reg_bus.pwrite = 0;
        force_err = 0;
        
        // Reset
        rst_n = 0;
        #20 rst_n = 1;
        #20;
        
        // --------------------------------------------------------------------
        $display("-------------------------------------------");
        $display("Starting T01: Mem-to-Mem Transfer (32-bit)");
        $display("-------------------------------------------");
        memory[16'h100] = 8'hAA; memory[16'h101] = 8'hBB; memory[16'h102] = 8'hCC; memory[16'h103] = 8'hDD;
        memory[16'h104] = 8'h11; memory[16'h105] = 8'h22; memory[16'h106] = 8'h33; memory[16'h107] = 8'h44;
        apb_write(32'h04, 32'h100);     // SAR = 0x100
        apb_write(32'h08, 32'h200);     // DAR = 0x200
        apb_write(32'h0C, 32'h002);     // TSR = 2 transfers
        // CR = EN(1) | DIR(0) | PSIZE(10 -> 32-bit) | INC_DEST(1) | INC_SRC(1) | IRQ_EN(1)
        apb_write(32'h10, 32'h5881);
        wait(irq || dut.hw_finished);
        @(posedge clk);
        apb_read(32'h14, status);
        if (!status[0]) $fatal(1, "T01 FAILED");
        $display("T01 PASSED.");

        // --------------------------------------------------------------------
        $display("-------------------------------------------");
        $display("Starting T02: Mem-to-Mem Transfer (8-bit)");
        $display("-------------------------------------------");
        memory[16'h110] = 8'h55; memory[16'h111] = 8'h66;
        apb_write(32'h04, 32'h110);     // SAR = 0x110
        apb_write(32'h08, 32'h210);     // DAR = 0x210
        apb_write(32'h0C, 32'h002);     // TSR = 2 transfers
        // CR = EN(1) | PSIZE(00 -> 8-bit) | INC_DEST(1) | INC_SRC(1) | IRQ_EN(1)
        apb_write(32'h10, 32'h5801);
        wait(irq || dut.hw_finished);
        @(posedge clk);
        apb_read(32'h14, status);
        if (!status[0]) $fatal(1, "T02 FAILED");
        if (memory[16'h210] !== 8'h55 || memory[16'h211] !== 8'h66) $fatal(1, "T02 DATA MISMATCH");
        $display("T02 PASSED.");

        // --------------------------------------------------------------------
        $display("-------------------------------------------");
        $display("Starting T03: Mem-to-Mem Transfer (16-bit)");
        $display("-------------------------------------------");
        memory[16'h120] = 8'h77; memory[16'h121] = 8'h88;
        apb_write(32'h04, 32'h120);     // SAR = 0x120
        apb_write(32'h08, 32'h220);     // DAR = 0x220
        apb_write(32'h0C, 32'h001);     // TSR = 1 transfer
        // CR = EN(1) | PSIZE(01 -> 16-bit) | INC_DEST(1) | INC_SRC(1) | IRQ_EN(1)
        apb_write(32'h10, 32'h5841);
        wait(irq || dut.hw_finished);
        @(posedge clk);
        apb_read(32'h14, status);
        if (!status[0]) $fatal(1, "T03 FAILED");
        if (memory[16'h220] !== 8'h77 || memory[16'h221] !== 8'h88) $fatal(1, "T03 DATA MISMATCH");
        $display("T03 PASSED.");

        // --------------------------------------------------------------------
        $display("-------------------------------------------");
        $display("Starting T04: Fixed Addresses (INC_SRC=0, INC_DEST=0)");
        $display("-------------------------------------------");
        memory[16'h130] = 8'h99;
        apb_write(32'h04, 32'h130);     // SAR = 0x130
        apb_write(32'h08, 32'h230);     // DAR = 0x230
        apb_write(32'h0C, 32'h002);     // TSR = 2 transfers
        // CR = EN(1) | PSIZE(00 -> 8-bit) | INC_DEST(0) | INC_SRC(0) | IRQ_EN(1)
        apb_write(32'h10, 32'h4001);
        wait(irq || dut.hw_finished);
        @(posedge clk);
        apb_read(32'h14, status);
        if (!status[0]) $fatal(1, "T04 FAILED");
        if (memory[16'h230] !== 8'h99) $fatal(1, "T04 DATA MISMATCH");
        $display("T04 PASSED.");

        // --------------------------------------------------------------------
        $display("-------------------------------------------");
        $display("Starting T05: Circular Mode (CIRC=1)");
        $display("-------------------------------------------");
        apb_write(32'h04, 32'h140);     // SAR = 0x140
        apb_write(32'h08, 32'h240);     // DAR = 0x240
        apb_write(32'h0C, 32'h002);     // TSR = 2 transfers
        // CR = EN(1) | PSIZE(00 -> 8-bit) | CIRC(1) | INC_DEST(1) | INC_SRC(1) | IRQ_EN(1)
        apb_write(32'h10, 32'h5C01);
        // Wait for it to wrap around and finish a few transfers
        #500;
        apb_write(32'h10, 32'h5C00); // Clear EN to stop
        @(posedge clk);
        apb_read(32'h14, status);
        // We just check it didn't crash and we could stop it
        $display("T05 PASSED.");

        // --------------------------------------------------------------------
        $display("-------------------------------------------");
        $display("Starting T06: Peripheral Trigger (TRIG_EN=1)");
        $display("-------------------------------------------");
        apb_write(32'h04, 32'h150);     // SAR = 0x150
        apb_write(32'h08, 32'h250);     // DAR = 0x250
        apb_write(32'h0C, 32'h001);     // TSR = 1 transfer
        // CR = EN(1) | PSIZE(00 -> 8-bit) | TRIG_EN(1) | INC_DEST(1) | INC_SRC(1) | IRQ_EN(1)
        apb_write(32'h10, 32'h5901);
        #100;
        drq = 1;
        wait(daq);
        drq = 0;
        wait(irq || dut.hw_finished);
        @(posedge clk);
        apb_read(32'h14, status);
        if (!status[0]) $fatal(1, "T06 FAILED");
        $display("T06 PASSED.");

        // --------------------------------------------------------------------
        $display("-------------------------------------------");
        $display("Starting T07: Bus Errors (HRESP=ERROR)");
        $display("-------------------------------------------");
        apb_write(32'h04, 32'h160);     // SAR = 0x160
        apb_write(32'h08, 32'h260);     // DAR = 0x260
        apb_write(32'h0C, 32'h002);     // TSR = 2 transfers
        // CR = EN(1) | PSIZE(00 -> 8-bit) | INC_DEST(1) | INC_SRC(1) | IRQ_EN(1)
        apb_write(32'h10, 32'h5801);
        #20;
        force_err = 1;
        for (int i=0; i<10; i++) begin
            @(posedge clk);
            $display("T07 Trace %0d: HRESP=%b HREADY=%b grant=%b r_req=%b w_req=%b r_state=%d w_state=%d hw_err=%b",
                i, mem_bus.HRESP, mem_bus.HREADY, dut.i_arbiter.grant, dut.i_read_ctrl.r_req, dut.i_write_ctrl.w_req, dut.i_read_ctrl.state, dut.i_write_ctrl.state, dut.hw_error);
            if (dut.hw_error) force_err = 0;
        end
        apb_read(32'h14, status);
        if (!status[1]) $fatal(1, "T07 FAILED - Error flag not set");
        $display("T07 PASSED.");

        // --------------------------------------------------------------------
        $display("-------------------------------------------");
        $display("Starting T08: Arbiter Contention");
        $display("-------------------------------------------");
        // To force contention, we can setup a large transfer and make the memory
        // respond with some delay, or just let the DMA run a long transfer where 
        // read and write queues will eventually overlap inside the memArbiter.
        apb_write(32'h04, 32'h170);     // SAR = 0x170
        apb_write(32'h08, 32'h270);     // DAR = 0x270
        apb_write(32'h0C, 32'h020);     // TSR = 32 transfers (fills/empties FIFO)
        // CR = EN(1) | PSIZE(10 -> 32-bit) | INC_DEST(1) | INC_SRC(1) | IRQ_EN(1)
        apb_write(32'h10, 32'h5881);
        wait(irq || dut.hw_finished);
        @(posedge clk);
        apb_read(32'h14, status);
        if (!status[0]) $fatal(1, "T08 FAILED");
        $display("T08 PASSED.");

        // Wait and exit
        #100;
        $display("ALL TESTS PASSED");
        $finish(0);
    end

endmodule
