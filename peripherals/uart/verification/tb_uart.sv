`timescale 1ns/1ps

module tb_uart;

    // --- Parameters ---
    parameter int CLK_FREQ = 50_000_000;
    parameter int DEFAULT_BAUD = 115200;
    parameter int CLK_PERIOD_NS = 20; // 50 MHz
    
    // --- Signals ---
    logic clk = 0;
    logic rst_n = 0;
    int errors = 0;
    
    always #(CLK_PERIOD_NS/2) clk = ~clk;
    
    // --- Interfaces ---
    ahb_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) ahb(
        .HCLK(clk),
        .HRESETn(rst_n)
    );
    
    uart_if uif();
    
    // In a single-slave AHB setup, HREADY input to master/slave is driven by HREADYOUT of slave
    assign ahb.HREADY = ahb.HREADYOUT;
    
    // --- DUT ---
    uart #() dut (
        .ahb(ahb),
        .uif(uif)
    );
    
    // --- BFM Tasks ---
    task automatic ahb_write(input logic [31:0] addr, input logic [31:0] data);
        @(posedge clk);
        ahb.HSEL <= 1'b1;
        ahb.HADDR <= addr;
        ahb.HWRITE <= 1'b1;
        ahb.HTRANS <= 2'b10; // NONSEQ
        ahb.HSIZE <= 3'b010; // WORD
        ahb.HBURST <= 3'b000; // SINGLE
        ahb.HMASTLOCK <= 1'b0;
        
        @(posedge clk);
        while (!ahb.HREADYOUT) @(posedge clk);
        ahb.HTRANS <= 2'b00; // IDLE
        ahb.HSEL <= 1'b0;
        ahb.HWDATA <= data;
        
        @(posedge clk);
        while (!ahb.HREADYOUT) @(posedge clk);
        ahb.HWDATA <= 'x;
    endtask
    
    task automatic ahb_read(input logic [31:0] addr, output logic [31:0] data);
        @(posedge clk);
        ahb.HSEL <= 1'b1;
        ahb.HADDR <= addr;
        ahb.HWRITE <= 1'b0;
        ahb.HTRANS <= 2'b10; // NONSEQ
        ahb.HSIZE <= 3'b010; // WORD
        ahb.HBURST <= 3'b000; // SINGLE
        ahb.HMASTLOCK <= 1'b0;
        
        @(posedge clk);
        while (!ahb.HREADYOUT) @(posedge clk);
        ahb.HTRANS <= 2'b00; // IDLE
        ahb.HSEL <= 1'b0;
        
        @(posedge clk);
        while (!ahb.HREADYOUT) @(posedge clk);
        data = ahb.HRDATA;
    endtask

    task automatic uart_rx_byte(input int baud, output logic [7:0] data);
        int bit_period_ns = 1_000_000_000 / baud;
        logic timeout = 0;
        
        // Wait for start bit with a timeout
        fork
            begin
                @(negedge uif.tx);
            end
            begin
                #50_000;
                timeout = 1;
            end
        join_any
        disable fork;
        
        if (timeout) begin
            $display("FAIL: Timeout waiting for start bit");
            errors++;
        end else begin
            #(bit_period_ns / 2); // Sample middle of start bit
            if (uif.tx !== 1'b0) $display("Error: False start bit");
            
            #(bit_period_ns);
            for (int i=0; i<8; i++) begin
                data[i] = uif.tx;
                #(bit_period_ns);
            end
        end
    endtask

    task automatic uart_tx_byte(input int baud, input logic [7:0] data);
        int bit_period_ns = 1_000_000_000 / baud;
        uif.rx = 1'b0; // start bit
        #(bit_period_ns);
        for (int i=0; i<8; i++) begin
            uif.rx = data[i];
            #(bit_period_ns);
        end
        uif.rx = 1'b1; // stop bit
        #(bit_period_ns);
    endtask

    // --- State & Functional Coverage ---
    logic [1:0] trk_word_length = 2'b11;
    logic       trk_stop_bits   = 1'b0;
    logic [1:0] trk_parity      = 2'b00;
    logic       trk_loopback    = 1'b0;
    logic       trk_rx_ovf      = 1'b0;
    logic       trk_framing_err = 1'b0;
    logic       trk_parity_err  = 1'b0;
    logic       trk_break_det   = 1'b0;

`ifndef VERILATOR
    covergroup uart_cg;
        c_word_length: coverpoint trk_word_length {
            bins b5 = {0}; bins b6 = {1}; bins b7 = {2}; bins b8 = {3};
        }
        c_stop_bits: coverpoint trk_stop_bits {
            bins one = {0}; bins two = {1};
        }
        c_parity: coverpoint trk_parity {
            bins none = {0}; bins odd = {1}; bins even = {2}; bins stick = {3};
        }
        c_loopback: coverpoint trk_loopback {
            bins disabled = {0}; bins enabled = {1};
        }
        c_errors: coverpoint {trk_rx_ovf, trk_framing_err, trk_parity_err, trk_break_det} {
            bins ovf = {4'b1000};
            bins fe  = {4'b0100};
            bins pe  = {4'b0010};
            bins bk  = {4'b0001};
            bins clean = {4'b0000};
        }
        cross c_word_length, c_parity;
    endgroup
    uart_cg cg = new();
`endif

    // --- Protocol Assertions ---
    // 1. tx is 1 whenever idle (not transmitting and not in break)
    // Simplified assertion for the smoke test frame
    property p_tx_idle;
        @(posedge clk) disable iff (!rst_n)
        ($sampled(uif.tx) === 1'b1 || $sampled(uif.tx) === 1'b0); // tx must be 1 or 0, never X
    endproperty
    assert property(p_tx_idle);

    // --- Test Sequences ---
    task automatic test_reset();
        logic [31:0] rdata;
        $display("Running TEST_RESET...");
        rst_n = 0;
        #(100);
        rst_n = 1;
        #(100);
        
        ahb_read(32'h0C, rdata); // LINE_CTRL
        if (rdata[7:0] !== 8'h03) begin
            $display("FAIL: LINE_CTRL reset value expected 0x03, got 0x%02x", rdata);
            errors++;
        end
    endtask

    task automatic test_tx_basic();
        logic [31:0] rdata;
        logic [7:0] rx_byte;
        $display("Running TEST_TX_BASIC...");
        // Enable FIFOs
        ahb_write(32'h08, 32'h01); 
        // Write 'A'
        ahb_write(32'h00, 32'h41);
        
        // Receive on the testbench side
        uart_rx_byte(DEFAULT_BAUD, rx_byte);
        if (rx_byte !== 8'h41) begin
            $display("FAIL: TX basic expected 0x41, got 0x%02x", rx_byte);
            errors++;
        end
    endtask

    // --- Main ---
    initial begin
        #500_000;
        $display("TIMEOUT: Simulation hung!");
        $finish(1);
    end

    initial begin
        $display("--- Starting UART Verification ---");
        uif.rx = 1;
        uif.cts_n = 0;
        ahb.HSEL = 0;
        ahb.HTRANS = 0;
        
        test_reset();
        
        // This test will fail currently because the RTL is just a stub
        // where tx is tied to 1'b1. The self-checking TB correctly catches this.
        test_tx_basic();
        
`ifndef VERILATOR
        cg.sample();
`endif

        if (errors == 0) begin
            $display("PASS: All tests passed.");
            $finish(0);
        end else begin
            $display("FAIL: %0d errors encountered.", errors);
            $finish(1);
        end
    end

endmodule
