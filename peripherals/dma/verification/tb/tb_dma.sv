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
    logic ahb_pending;
    logic [ADDR_W-1:0] ahb_addr_r;
    logic ahb_write_r;
    logic [2:0] ahb_size_r;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_bus.HREADY <= 1'b1;
            mem_bus.HRESP <= 1'b0;
            mem_bus.HRDATA <= '0;
            ahb_pending <= 1'b0;
            for(int i=0; i<1024; i++) memory[i] <= 8'h00;
        end else begin
            // Simple zero-wait state AHB Completer
            if (mem_bus.HTRANS == 2'b10 || mem_bus.HTRANS == 2'b11) begin // NONSEQ or SEQ
                ahb_pending <= 1'b1;
                ahb_addr_r <= mem_bus.HADDR;
                ahb_write_r <= mem_bus.HWRITE;
                ahb_size_r <= mem_bus.HSIZE;
            end else begin
                ahb_pending <= 1'b0;
            end
            
            if (ahb_pending && ahb_write_r) begin
                // Write Data Phase
                if (ahb_size_r == 3'b000) begin // 8-bit
                    memory[ahb_addr_r[9:0]] <= mem_bus.HWDATA[7:0];
                end else if (ahb_size_r == 3'b001) begin // 16-bit
                    memory[ahb_addr_r[9:0]] <= mem_bus.HWDATA[7:0];
                    memory[ahb_addr_r[9:0]+1] <= mem_bus.HWDATA[15:8];
                end else begin // 32-bit
                    memory[ahb_addr_r[9:0]] <= mem_bus.HWDATA[7:0];
                    memory[ahb_addr_r[9:0]+1] <= mem_bus.HWDATA[15:8];
                    memory[ahb_addr_r[9:0]+2] <= mem_bus.HWDATA[23:16];
                    memory[ahb_addr_r[9:0]+3] <= mem_bus.HWDATA[31:24];
                end
                ahb_pending <= 1'b0; // Done
            end else if (ahb_pending && !ahb_write_r) begin
                // Read Data Phase
                if (ahb_size_r == 3'b000) begin // 8-bit
                    mem_bus.HRDATA <= {24'h0, memory[ahb_addr_r[9:0]]};
                end else if (ahb_size_r == 3'b001) begin // 16-bit
                    mem_bus.HRDATA <= {16'h0, memory[ahb_addr_r[9:0]+1], memory[ahb_addr_r[9:0]]};
                end else begin // 32-bit
                    mem_bus.HRDATA <= {memory[ahb_addr_r[9:0]+3], memory[ahb_addr_r[9:0]+2], memory[ahb_addr_r[9:0]+1], memory[ahb_addr_r[9:0]]};
                end
                ahb_pending <= 1'b0; // Done
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
        reg_bus.paddr <= addr;
        reg_bus.pwdata <= data;
        reg_bus.pwrite <= 1'b1;
        reg_bus.psel <= 1'b1;
        reg_bus.penable <= 1'b0;
        @(posedge clk);
        reg_bus.penable <= 1'b1;
        wait(reg_bus.pready);
        @(posedge clk);
        reg_bus.psel <= 1'b0;
        reg_bus.penable <= 1'b0;
    endtask

    task apb_read(input logic [31:0] addr, output logic [31:0] data);
        @(posedge clk);
        reg_bus.paddr <= addr;
        reg_bus.pwrite <= 1'b0;
        reg_bus.psel <= 1'b1;
        reg_bus.penable <= 1'b0;
        @(posedge clk);
        reg_bus.penable <= 1'b1;
        wait(reg_bus.pready);
        data = reg_bus.prdata;
        @(posedge clk);
        reg_bus.psel <= 1'b0;
        reg_bus.penable <= 1'b0;
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
        
        // Reset
        rst_n = 0;
        #20 rst_n = 1;
        #20;
        
        $display("-------------------------------------------");
        $display("Starting T01: Mem-to-Mem Transfer (32-bit)");
        $display("-------------------------------------------");
        
        // Setup source memory at 0x100
        memory[16'h100] = 8'hAA; memory[16'h101] = 8'hBB; memory[16'h102] = 8'hCC; memory[16'h103] = 8'hDD;
        memory[16'h104] = 8'h11; memory[16'h105] = 8'h22; memory[16'h106] = 8'h33; memory[16'h107] = 8'h44;

        // Init DMA
        apb_write(32'h04, 32'h100);     // SAR = 0x100
        apb_write(32'h08, 32'h200);     // DAR = 0x200
        apb_write(32'h0C, 32'h002);     // TSR = 2 transfers (units)
        
        // CR = EN(1) | DIR(0) | PSIZE(10 -> 32-bit) | INC_DEST(1) | INC_SRC(1) | IRQ_EN(1)
        // CR = bit 0 | bit 4:0 | bit 7:6=2'b10 | bit 11:1 | bit 12:1 | bit 14:1
        // EN=1(bit 0), DIR=0(bit 4), PSIZE=2'b10(bits 7:6 -> 0x80), INC_DEST=1(bit 11 -> 0x800), INC_SRC=1(bit 12 -> 0x1000), IRQ_EN=1(bit 14 -> 0x4000)
        // Total = 0x4000 | 0x1000 | 0x800 | 0x80 | 1 = 0x5881
        apb_write(32'h10, 32'h5881);
        
        // Wait for IRQ or Finished
        wait(irq || dut.hw_finished);
        @(posedge clk);
        
        // Read Status
        apb_read(32'h14, status);
        if (status[0]) $display("Transfer Finished Successfully!");
        else $error("Transfer finished without status bit 0 set!");
        
        // Check Destination Memory
        if ({memory[16'h203], memory[16'h202], memory[16'h201], memory[16'h200]} !== 32'hDDCCBBAA) begin
            $error("Data mismatch at 0x200: %x", {memory[16'h203], memory[16'h202], memory[16'h201], memory[16'h200]});
            $fatal(1, "TEST FAILED");
        end
        if ({memory[16'h207], memory[16'h206], memory[16'h205], memory[16'h204]} !== 32'h44332211) begin
            $error("Data mismatch at 0x204: %x", {memory[16'h207], memory[16'h206], memory[16'h205], memory[16'h204]});
            $fatal(1, "TEST FAILED");
        end
        
        $display("T01 (32-bit) PASSED.");
        
        // Wait and exit
        #100;
        $display("ALL TESTS PASSED");
        $finish(0); // Exit 0 on success
    end

endmodule
