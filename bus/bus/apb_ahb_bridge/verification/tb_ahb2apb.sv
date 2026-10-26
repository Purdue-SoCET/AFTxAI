`timescale 1ns/1ps

module tb_ahb2apb;

    parameter int ADDR_WIDTH = 32;
    parameter int DATA_WIDTH = 32;
    parameter logic [ADDR_WIDTH-1:0] BASE_ADDR = 32'h8000_0000;
    parameter int FIFO_DEPTH = 16;
    parameter int NWORDS = 4096;
    parameter int STRB_WIDTH = DATA_WIDTH / 8;
    localparam logic [ADDR_WIDTH-1:0] TOP_ADDR = BASE_ADDR + NWORDS * STRB_WIDTH;

    logic hclk = 0;
    logic pclk = 0;
    logic hresetn = 0;
    logic presetn = 0;

    always #5 hclk = ~hclk;   // 100MHz AHB
    always #7 pclk = ~pclk;   // ~71MHz APB (asynchronous)

    ahb_if #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) ahbif(hclk, hresetn);
    apb_if #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) apbif(pclk, presetn);

    ahb2apb #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .BASE_ADDR(BASE_ADDR),
        .FIFO_DEPTH(FIFO_DEPTH),
        .NWORDS(NWORDS)
    ) dut (
        .ahbif(ahbif),
        .apbif(apbif)
    );

    // Default driver assignments
    initial begin
        ahbif.HSEL = 0;
        ahbif.HTRANS = 0;
        ahbif.HADDR = 0;
        ahbif.HWRITE = 0;
        ahbif.HWDATA = 0;
        ahbif.HWSTRB = 0;
        ahbif.HREADY = 1;

        apbif.PREADY = 0;
        apbif.PRDATA = 0;
        apbif.PSLVERR = 0;
    end

    // AHB Driver Task
    task automatic ahb_access(
        input logic [ADDR_WIDTH-1:0] addr,
        input logic write,
        input logic [DATA_WIDTH-1:0] wdata,
        input logic [STRB_WIDTH-1:0] wstrb,
        output logic [DATA_WIDTH-1:0] rdata,
        output logic error
    );
        // Address Phase
        @(posedge hclk);
        ahbif.HSEL <= 1;
        ahbif.HTRANS <= 2'b10; // NONSEQ
        ahbif.HADDR <= addr;
        ahbif.HWRITE <= write;
        ahbif.HWSTRB <= write ? wstrb : '0;
        ahbif.HREADY <= 1;

        // Wait for address phase to be accepted
        forever begin
            @(posedge hclk);
            if (ahbif.HREADYOUT) break;
        end

        // Data Phase
        ahbif.HSEL <= 0;
        ahbif.HTRANS <= 2'b00; // IDLE
        if (write) ahbif.HWDATA <= wdata;

        // Wait for data phase completion
        forever begin
            @(posedge hclk);
            if (ahbif.HREADYOUT) begin
                rdata = ahbif.HRDATA;
                error = ahbif.HRESP;
                break;
            end
        end
    endtask

    // APB Completer Logic (Simulated Target)
    logic apb_inject_error = 0;
    logic [DATA_WIDTH-1:0] apb_mem [logic [ADDR_WIDTH-1:0]];

    always @(posedge pclk) begin
        if (!presetn) begin
            apbif.PREADY <= 0;
            apbif.PSLVERR <= 0;
        end else begin
            if (apbif.PSEL && !apbif.PENABLE) begin
                // SETUP phase, move to ACCESS phase
                apbif.PREADY <= 0;
            end else if (apbif.PSEL && apbif.PENABLE) begin
                // ACCESS phase
                // Add random delay later, for now immediate ready
                apbif.PREADY <= 1;
                apbif.PSLVERR <= apb_inject_error;
                
                if (apbif.PWRITE) begin
                    apb_mem[apbif.PADDR] = apbif.PWDATA;
                end else begin
                    apbif.PRDATA <= apb_mem.exists(apbif.PADDR) ? apb_mem[apbif.PADDR] : 32'hDEADBEEF;
                end
            end else begin
                apbif.PREADY <= 0;
                apbif.PSLVERR <= 0;
            end
        end
    end

    // Coverage
    covergroup cg_ahb_apb_bridge @(posedge hclk);
        cp_hwrite: coverpoint ahbif.HWRITE {
            bins read = {0};
            bins write = {1};
        }
        cp_hresp: coverpoint ahbif.HRESP {
            bins ok = {0};
            bins err = {1};
        }
        cp_align: coverpoint (ahbif.HADDR % 4) {
            bins aligned = {0};
            bins unaligned = {[1:3]};
        }
        cp_range: coverpoint (ahbif.HADDR >= BASE_ADDR && ahbif.HADDR < TOP_ADDR) {
            bins in_range = {1};
            bins out_of_range = {0};
        }
        cross cp_hwrite, cp_hresp, cp_range, cp_align;
    endgroup

    cg_ahb_apb_bridge cg = new();

    // Test Sequence
    int fails = 0;
    logic [DATA_WIDTH-1:0] rd_val;
    logic err_val;

    initial begin
        $display("Starting AHB-to-APB Bridge Tests...");
        
        // Reset
        hresetn = 0;
        presetn = 0;
        #20;
        hresetn = 1;
        presetn = 1;
        #20;

        // T01: Basic Write
        $display("T01: Basic Write (Aligned, In Range)");
        ahb_access(BASE_ADDR + 32'h10, 1, 32'h12345678, 4'hF, rd_val, err_val);
        if (err_val) begin $display("FAIL: T01 unexpected error"); fails++; end

        // T02: Basic Read
        $display("T02: Basic Read (Aligned, In Range)");
        ahb_access(BASE_ADDR + 32'h10, 0, 0, 4'h0, rd_val, err_val);
        if (err_val || rd_val !== 32'h12345678) begin 
            $display("FAIL: T02 expected 12345678, got %h, err=%b", rd_val, err_val); 
            fails++; 
        end

        // T03: Address Out of Range
        $display("T03: Address Out of Range");
        ahb_access(BASE_ADDR - 32'h10, 1, 32'hAAAAAAAA, 4'hF, rd_val, err_val);
        if (!err_val) begin $display("FAIL: T03 expected error"); fails++; end

        // T04: Address Misaligned
        $display("T04: Address Misaligned");
        ahb_access(BASE_ADDR + 32'h11, 1, 32'hBBBBBBBB, 4'hF, rd_val, err_val);
        if (!err_val) begin $display("FAIL: T04 expected error"); fails++; end

        // T05: APB Target Error
        $display("T05: APB Target Error");
        apb_inject_error = 1;
        ahb_access(BASE_ADDR + 32'h20, 1, 32'hCCCCCCCC, 4'hF, rd_val, err_val);
        if (!err_val) begin $display("FAIL: T05 expected error"); fails++; end
        apb_inject_error = 0;

        // Finish
        if (fails == 0) begin
            $display("PASS: All tests completed successfully.");
        end else begin
            $display("FAIL: %0d tests failed.", fails);
        end
        
        $finish(fails != 0);
    end

endmodule
