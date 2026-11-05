`timescale 1ns/1ps

module tb_ahb2apb;

    // Parameters
    localparam int ADDR_WIDTH = 32;
    localparam int DATA_WIDTH = 32;
    localparam logic [ADDR_WIDTH-1:0] BASE_ADDR = 32'h8000_0000;
    localparam int NWORDS = 4096;

    // Clocks and resets
    logic HCLK;
    logic HRESETn;
    logic pclk;
    logic presetn;

    // Interfaces
    ahb_if #(ADDR_WIDTH, DATA_WIDTH) ahb (HCLK, HRESETn);
    apb_if #(ADDR_WIDTH, DATA_WIDTH) apb (pclk, presetn);

    // Instantiate DUT
    ahb2apb #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .BASE_ADDR(BASE_ADDR),
        .FIFO_DEPTH(4),
        .NWORDS(NWORDS)
    ) dut (
        .ahbif(ahb.subordinate),
        .apbif(apb)
    );

    // Global HREADY tie
    assign ahb.HREADY = ahb.HREADYOUT;

    // Clock generation
    initial begin
        HCLK = 0;
        forever #5 HCLK = ~HCLK; // 100MHz
    end

    initial begin
        pclk = 0;
        forever #7 pclk = ~pclk; // Asynchronous ~71MHz
    end

    // Error tracking
    int err_count = 0;

    // APB Target Model
    logic [DATA_WIDTH-1:0] apb_mem [0:NWORDS-1];
    logic force_pslverr = 0;
    int   apb_delay = 0;

    initial begin
        apb.PREADY = 1;
        apb.PRDATA = '0;
        apb.PSLVERR = 0;
        forever begin
            @(posedge pclk);
            if (apb.PSEL && !apb.PENABLE) begin
                // SETUP phase
                apb.PREADY <= 0;
                apb.PSLVERR <= 0;
            end
            else if (apb.PSEL && apb.PENABLE) begin
                // ACCESS phase
                if (apb_delay > 0) begin
                    apb_delay--;
                    apb.PREADY <= 0;
                end else begin
                    apb.PREADY <= 1;
                    if (force_pslverr) begin
                        apb.PSLVERR <= 1;
                    end else begin
                        apb.PSLVERR <= 0;
                        if (apb.PWRITE) begin
                            // Write
                            logic [31:0] word;
                            word = apb_mem[apb.PADDR[13:2]];
                            for (int i=0; i<4; i++) begin
                                if (apb.PSTRB[i]) word[i*8 +: 8] = apb.PWDATA[i*8 +: 8];
                            end
                            apb_mem[apb.PADDR[13:2]] = word;
                        end else begin
                            // Read
                            apb.PRDATA <= apb_mem[apb.PADDR[13:2]];
                        end
                    end
                end
            end else begin
                apb.PREADY <= 1;
                apb.PSLVERR <= 0;
            end
        end
    end

    // AHB Manager Tasks
    task ahb_write(input logic [31:0] addr, input logic [31:0] data, input logic [3:0] strb, output logic err);
        @(posedge HCLK);
        ahb.HSEL <= 1;
        ahb.HTRANS <= 2'b10; // NONSEQ
        ahb.HADDR <= addr;
        ahb.HWRITE <= 1;
        ahb.HSIZE <= 3'b010; // WORD
        ahb.HWSTRB <= strb;
        
        @(posedge HCLK);
        while (!ahb.HREADY) @(posedge HCLK);
        
        ahb.HTRANS <= 2'b00; // IDLE
        ahb.HWDATA <= data;
        
        @(posedge HCLK);
        while (!ahb.HREADY) @(posedge HCLK);
        
        err = ahb.HRESP;
        ahb.HSEL <= 0;
    endtask

    task ahb_read(input logic [31:0] addr, output logic [31:0] data, output logic err);
        @(posedge HCLK);
        ahb.HSEL <= 1;
        ahb.HTRANS <= 2'b10; // NONSEQ
        ahb.HADDR <= addr;
        ahb.HWRITE <= 0;
        ahb.HSIZE <= 3'b010; // WORD
        ahb.HWSTRB <= '0;
        
        @(posedge HCLK);
        while (!ahb.HREADY) @(posedge HCLK);
        
        ahb.HTRANS <= 2'b00; // IDLE
        
        @(posedge HCLK);
        while (!ahb.HREADY) @(posedge HCLK);
        
        data = ahb.HRDATA;
        err = ahb.HRESP;
        ahb.HSEL <= 0;
    endtask

    // Functional coverage
    covergroup cg_bridge @(posedge HCLK);
        option.per_instance = 1;
        cp_hwrite: coverpoint ahb.HWRITE {
            bins read = {0};
            bins write = {1};
        }
        cp_hstrb: coverpoint ahb.HWSTRB {
            bins all_bytes = {4'b1111};
            bins single_byte = {4'b0001, 4'b0010, 4'b0100, 4'b1000};
        }
        cp_haddr_range: coverpoint ahb.HADDR {
            bins in_range = {[BASE_ADDR : BASE_ADDR + (NWORDS*4) - 1]};
            bins below_range = {[0 : BASE_ADDR - 1]};
            bins above_range = {[BASE_ADDR + (NWORDS*4) : 32'hFFFF_FFFF]};
        }
        cp_misaligned: coverpoint ahb.HADDR[1:0] {
            bins aligned = {2'b00};
            bins unaligned = {2'b01, 2'b10, 2'b11};
        }
        cp_error: coverpoint ahb.HRESP {
            bins ok = {0};
            bins err = {1};
        }
        cross cp_hwrite, cp_haddr_range;
    endgroup

    cg_bridge cg = new();

    // Simulation timeout
    initial begin
        #50000;
        $display("FAIL: Simulation timed out. Deadlock in DUT or testbench.");
        $fatal(1, "Simulation timed out");
    end

    // Test sequence
    initial begin
        // Init signals
        ahb.HSEL = 0;
        ahb.HTRANS = 2'b00;
        ahb.HADDR = '0;
        ahb.HWRITE = 0;
        ahb.HWDATA = '0;
        ahb.HWSTRB = '0;
        ahb.HSIZE = 3'b010;

        // Reset
        HRESETn = 0;
        presetn = 0;
        #20;
        HRESETn = 1;
        presetn = 1;
        #20;

        // Smoke test 1: Valid Write
        $display("Running valid write test...");
        begin
            logic err;
            ahb_write(32'h8000_0004, 32'hDEADBEEF, 4'b1111, err);
            if (err) begin
                $display("FAIL: Unexpected error on valid write");
                err_count++;
            end
        end

        // Smoke test 2: Valid Read
        $display("Running valid read test...");
        begin
            logic [31:0] rdata;
            logic err;
            ahb_read(32'h8000_0004, rdata, err);
            if (err || rdata !== 32'hDEADBEEF) begin
                $display("FAIL: Read mismatch. Exp: DEADBEEF, Act: %h, err: %b", rdata, err);
                err_count++;
            end
        end

        // Smoke test 3: Out of range Write
        $display("Running out of range test...");
        begin
            logic err;
            ahb_write(32'h4000_0000, 32'hCAFEBA11, 4'b1111, err);
            if (!err) begin
                $display("FAIL: Expected error on out of range write");
                err_count++;
            end
        end

        // Test 4: Above range Write
        $display("Running above range test...");
        begin
            logic err;
            ahb_write(BASE_ADDR + (NWORDS*4) + 16, 32'hBADC0DE0, 4'b1111, err);
            if (!err) begin
                $display("FAIL: Expected error on above range write");
                err_count++;
            end
        end

        // Test 5: Misaligned Write
        $display("Running misaligned test...");
        begin
            logic err;
            ahb_write(BASE_ADDR + 1, 32'hBADC0DE1, 4'b1111, err);
            if (!err) begin
                $display("FAIL: Expected error on misaligned write");
                err_count++;
            end
        end

        // Test 6: Single byte Write and Read
        $display("Running single byte test...");
        begin
            logic err;
            logic [31:0] rdata;
            ahb_write(BASE_ADDR + 8, 32'hAABBCCDD, 4'b0010, err);
            if (err) err_count++;
            ahb_read(BASE_ADDR + 8, rdata, err);
            if (err || (rdata & 32'h0000FF00) !== 32'h0000CC00) begin
                $display("FAIL: Single byte write/read mismatch. Exp byte: CC, Act: %h, err: %b", rdata, err);
                err_count++;
            end
        end

        // Test 7: PSLVERR error
        $display("Running PSLVERR test...");
        begin
            logic err;
            force_pslverr = 1;
            ahb_write(BASE_ADDR + 12, 32'h00000000, 4'b1111, err);
            force_pslverr = 0;
            if (!err) begin
                $display("FAIL: Expected AHB error from PSLVERR");
                err_count++;
            end
        end

        // Test 8: Backpressure
        $display("Running backpressure test...");
        begin
            logic err;
            apb_delay = 5;
            ahb_write(BASE_ADDR + 16, 32'h11223344, 4'b1111, err);
            if (err) begin
                $display("FAIL: Unexpected error with backpressure");
                err_count++;
            end
        end

        // Test 9: Out of range Read
        $display("Running out of range read test...");
        begin
            logic [31:0] rdata;
            logic err;
            ahb_read(32'h4000_0000, rdata, err);
            if (!err) begin
                $display("FAIL: Expected error on out of range read");
                err_count++;
            end
        end

        // Test 10: Above range Read
        $display("Running above range read test...");
        begin
            logic [31:0] rdata;
            logic err;
            ahb_read(BASE_ADDR + (NWORDS*4) + 16, rdata, err);
            if (!err) begin
                $display("FAIL: Expected error on above range read");
                err_count++;
            end
        end

        // Report
        if (err_count == 0) begin
            $display("========================");
            $display(" PASS ");
            $display("========================");
        end else begin
            $display("========================");
            $display(" FAIL (%0d errors)", err_count);
            $display("========================");
            $fatal(1, "Test failed");
        end
        $finish;
    end

endmodule
