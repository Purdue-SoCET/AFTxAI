`timescale 1ns/1ps

module gpio_integration_tb;

    logic hclk, pclk, hresetn, presetn;
    
    // Clocks
    initial begin
        hclk = 0;
        forever #5 hclk = ~hclk; // 100 MHz
    end
    
    initial begin
        pclk = 0;
        forever #40 pclk = ~pclk; // 12.5 MHz
    end

    // Resets
    initial begin
        hresetn = 0;
        presetn = 0;
        #100;
        @(posedge pclk);
        hresetn = 1;
        presetn = 1;
    end

    // Interfaces
    ahb_if #( .ADDR_WIDTH(32), .DATA_WIDTH(32) ) ahb ( .HCLK(hclk), .HRESETn(hresetn) );
    apb_if #( .ADDR_WIDTH(32), .DATA_WIDTH(32) ) apb ( .PCLK(pclk), .PRESETn(presetn) );
    apb_if #( .ADDR_WIDTH(32), .DATA_WIDTH(32) ) apb_comp[4] ( .PCLK(pclk), .PRESETn(presetn) );

    // Tracking variables for accepted vs completed transactions
    int ahb_requests = 0;
    int ahb_completions = 0;

    always @(posedge hclk) begin
        if (hresetn) begin
            if (ahb.HSEL && ahb.HREADY && (ahb.HTRANS == 2'b10 || ahb.HTRANS == 2'b11)) begin
                ahb_requests++;
            end
            if (ahb.HREADYOUT && ahb.HTRANS != 2'b00 && ahb.HTRANS != 2'b01) begin
                ahb_completions++;
            end
        end
    end

    // AHB to APB Bridge
    ahb2apb #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .BASE_ADDR(32'h8000_0000),
        .FIFO_DEPTH(16),
        .NWORDS(4096)
    ) bridge (
        .ahbif(ahb.subordinate),
        .apbif(apb.requester)
    );

    // APB Interconnect
    // Maps GPIO0..3 to 0x000, 0x100, 0x200, 0x300 bridge-relative offsets
    localparam logic [31:0] apb_map [4] = '{32'h0000_0300, 32'h0000_0200, 32'h0000_0100, 32'h0000_0000};
    
    apb_interconnect #(
        .NCOMPLETERS(4),
        .COMPLETER_ADDR_BITS(8),
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .APB_MAP(apb_map)
    ) i_interconnect (
        .requester(apb.completer),
        .completers(apb_comp)
    );

    // GPIO Signals
    logic [31:0] gpio_in[4];
    logic [31:0] gpio_out[4];
    logic [31:0] gpio_oe[4];
    logic [31:0] gpio_pull_up[4];
    logic [31:0] gpio_pull_down[4];
    logic [3:0]  gpio_irq;
    logic [3:0]  gpio_irq_sync;

    // 4 GPIO Banks
    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : gen_gpio
            localparam int W = (i==0) ? 32 : (i==1) ? 16 : (i==2) ? 7 : 1;
            
            logic [W-1:0] w_in, w_out, w_oe, w_pu, w_pd;
            
            gpio_apb_wrapper #(
                .GPIO_WIDTH(W)
            ) wrapper (
                .pclk(pclk),
                .presetn(presetn),
                .apb(apb_comp[3-i].completer),
                .gpio_in_i(w_in),
                .gpio_out_o(w_out),
                .gpio_oe_o(w_oe),
                .gpio_pull_up_o(w_pu),
                .gpio_pull_down_o(w_pd),
                .irq_o(gpio_irq[i])
            );
            
            assign w_in = gpio_in[i][W-1:0];
            assign gpio_out[i] = { {(32-W){1'b0}}, w_out };
            assign gpio_oe[i] = { {(32-W){1'b0}}, w_oe };
            assign gpio_pull_up[i] = { {(32-W){1'b0}}, w_pu };
            assign gpio_pull_down[i] = { {(32-W){1'b0}}, w_pd };
            
            // Proper CDC synchronizer for GPIO IRQ (PCLK domain) to PLIC (HCLK domain)
            sync_2ff #(
                .WIDTH(1)
            ) irq_sync (
                .clk(hclk),
                .rst_n(hresetn),
                .d_in(gpio_irq[i]),
                .d_out(gpio_irq_sync[i])
            );
        end
    endgenerate

    // PLIC instance
    bus_protocol_if #( .ADDR_WIDTH(32), .DATA_WIDTH(32) ) plic_bus ();
    plic_if irq_if ();
    
    // Assign synchronized interrupts to PLIC (1-4)
    assign irq_if.irq_source = {27'd0, gpio_irq_sync, 1'b0};
    
    plic i_plic (
        .clk(hclk),
        .nrst(hresetn),
        .bus(plic_bus.peripheral_vital),
        .irq_if(irq_if.plic)
    );

    // Test sequence
    task ahb_write(input logic [31:0] addr, input logic [31:0] data, input logic [3:0] strb);
        @(posedge hclk);
        while (!ahb.HREADYOUT) @(posedge hclk);
        ahb.HADDR <= addr;
        ahb.HTRANS <= 2'b10; // NONSEQ
        ahb.HWRITE <= 1;
        ahb.HSIZE <= 3'b010; // Word
        ahb.HBURST <= 3'b000; // SINGLE
        ahb.HWSTRB <= strb;
        ahb.HSEL <= 1;
        ahb.HREADY <= 1;
        
        @(posedge hclk);
        while (!ahb.HREADYOUT) @(posedge hclk);
        ahb.HTRANS <= 2'b00; // IDLE
        ahb.HWDATA <= data;
        
        @(posedge hclk);
        while (!ahb.HREADYOUT) @(posedge hclk);
    endtask
    
    task ahb_read(input logic [31:0] addr, output logic [31:0] data, output logic err);
        @(posedge hclk);
        while (!ahb.HREADYOUT) @(posedge hclk);
        ahb.HADDR <= addr;
        ahb.HTRANS <= 2'b10; // NONSEQ
        ahb.HWRITE <= 0;
        ahb.HSIZE <= 3'b010; // Word
        ahb.HBURST <= 3'b000;
        ahb.HWSTRB <= 0;
        ahb.HSEL <= 1;
        ahb.HREADY <= 1;
        
        @(posedge hclk);
        while (!ahb.HREADYOUT) @(posedge hclk);
        ahb.HTRANS <= 2'b00; // IDLE
        ahb.HWSTRB <= 0;
        
        @(posedge hclk);
        while (!ahb.HREADYOUT) @(posedge hclk);
        data = ahb.HRDATA;
        err = ahb.HRESP;
    endtask

    // PLIC accesses
    task plic_write(input logic [31:0] addr, input logic [31:0] data);
        @(posedge hclk);
        plic_bus.addr = addr;
        plic_bus.wdata = data;
        plic_bus.wen = 1;
        plic_bus.ren = 0;
        plic_bus.strobe = 4'hf;
        @(posedge hclk);
        plic_bus.wen = 0;
        @(posedge hclk);
    endtask
    
    task plic_read(input logic [31:0] addr, output logic [31:0] data);
        @(posedge hclk);
        plic_bus.addr = addr;
        plic_bus.wen = 0;
        plic_bus.ren = 1;
        @(posedge hclk);
        data = plic_bus.rdata;
        plic_bus.ren = 0;
        @(posedge hclk);
    endtask

    logic [31:0] rdata;
    logic err;
    int test_fails = 0;
    
    initial begin
        ahb.HADDR = 0;
        ahb.HTRANS = 0;
        ahb.HWRITE = 0;
        ahb.HSIZE = 0;
        ahb.HBURST = 0;
        ahb.HWDATA = 0;
        ahb.HWSTRB = 0;
        ahb.HSEL = 0;
        ahb.HREADY = 1;
        
        plic_bus.addr = 0;
        plic_bus.wdata = 0;
        plic_bus.wen = 0;
        plic_bus.ren = 0;
        plic_bus.strobe = 4'hf;
        
        for (int j=0; j<4; j++) gpio_in[j] = 0;

        #200;
        
        if ($test$plusargs("EXPECT_FAILURE")) begin
            $display("Running Intentional Failure Check Mode");
            $error("Intentional Error for regression validation.");
            $finish(1);
        end

        // 1. Basic AHB write to GPIO0 DIR
        $display("Test 1: Write to GPIO0 DIR (0x8000_0008)");
        ahb_write(32'h8000_0008, 32'hA5A5_5A5A, 4'hF);
        ahb_read(32'h8000_0008, rdata, err);
        if (err || rdata !== 32'hA5A5_5A5A) begin
            $error("Test 1 Failed: expected A5A5_5A5A, got %h, err %b", rdata, err);
            test_fails++;
        end

        // 2. Test GPIO3 width masking (Width = 1)
        $display("Test 2: Write to GPIO3 DIR (0x8000_0308)");
        ahb_write(32'h8000_0308, 32'hFFFF_FFFF, 4'hF);
        ahb_read(32'h8000_0308, rdata, err);
        if (err || rdata !== 32'h0000_0001) begin
            $error("Test 2 Failed: expected 0000_0001 (masked to 1 bit), got %h", rdata);
            test_fails++;
        end

        // 3. Test GPIO1 (Width = 16) DATA_OUT
        $display("Test 3: Write to GPIO1 DATA_OUT (0x8000_0104)");
        ahb_write(32'h8000_0108, 32'hFFFF_FFFF, 4'hF); // DIR = all 1s
        ahb_write(32'h8000_0104, 32'hDEAD_BEEF, 4'hF);
        #100;
        if (gpio_out[1] !== 32'h0000_BEEF) begin
            $error("Test 3 Failed: expected gpio_out[1]=BEEF, got %h", gpio_out[1]);
            test_fails++;
        end
        
        // 4. Test error response on invalid address (0x8000_000C is WO OUT_SET, read should fail)
        $display("Test 4: Error response on read to WO register");
        ahb_read(32'h8000_000C, rdata, err);
        if (!err) begin
            $error("Test 4 Failed: Expected error on reading WO register");
            test_fails++;
        end
        
        // 5. Test Interrupt flow (GPIO2 -> PLIC)
        $display("Test 5: Interrupt Flow (GPIO2 High Level)");
        ahb_write(32'h8000_022C, 32'h0000_0008, 4'hF); // IRQ High Enable bit 3
        plic_write(32'h0000_0010, 32'h0000_0007);      // Priority of src 4 to 7
        plic_write(32'h0020_0000, 32'h0000_0000);      // Threshold to 0
        plic_write(32'h0000_2000, 32'h0000_0010);      // Enable Source 4
        
        #100;
        gpio_in[2] = 32'h0000_0008; // Crosses sync_2ff
        #500;
        
        if (!irq_if.irq_target) begin
            $error("Test 5 Failed: PLIC irq_target did not assert");
            test_fails++;
        end
        
        plic_read(32'h0020_0004, rdata); // Claim
        if (rdata !== 32'h0000_0004) begin
            $error("Test 5 Failed: Claimed ID was %d, expected 4", rdata);
            test_fails++;
        end
        
        gpio_in[2] = 32'h0000_0000;
        #500;
        
        plic_write(32'h0020_0004, 32'h0000_0004); // Complete
        #100;
        if (irq_if.irq_target) begin
            $error("Test 5 Failed: PLIC irq_target still asserted after complete");
            test_fails++;
        end
        
        // 6. Test Unmapped / high-alias address handling
        $display("Test 6: Unmapped/high-alias address");
        // GPIO0 is at 0x8000_0000 - 0x8000_00FF. 
        // 0x8000_0800 should be unmapped in our 4-completer layout.
        ahb_read(32'h8000_0800, rdata, err);
        if (!err) begin
            $error("Test 6 Failed: Expected error for unmapped APB region 0x8000_0800");
            test_fails++;
        end
        
        // 7. Verify AHB Transaction Count
        $display("Test 7: Verification of accepted transaction count");
        if (ahb_requests != ahb_completions) begin
            $error("Test 7 Failed: ahb_requests (%d) != ahb_completions (%d)", ahb_requests, ahb_completions);
            test_fails++;
        end
        
        if (test_fails > 0) begin
            $display("TEST FAILED with %d errors", test_fails);
            $finish(1);
        end else begin
            $display("TEST PASSED");
            $finish(0);
        end
    end

endmodule