`timescale 1ns/1ps

module tb_aft_top;

    logic ext_clk;
    logic ext_rst_n;

    aft_top_if top_if();

    assign top_if.HCLK = ext_clk;
    assign top_if.HRESETn = ext_rst_n;

    aft_top u_dut (
        .intf(top_if)
    );

    // Clock generation
    initial begin
        ext_clk = 0;
        forever #5 ext_clk = ~ext_clk; // 100MHz HCLK
    end

    // Reset generation
    initial begin
        ext_rst_n = 0;
        #25 ext_rst_n = 1;
    end

    // Simple test sequence for S3 Bringup
    initial begin
        // Initialize TB manager signals
        top_if.tb_hsel = 1'b0;
        top_if.tb_haddr = '0;
        top_if.tb_hwdata = '0;
        top_if.tb_hwstrb = '0;
        top_if.tb_hwrite = 1'b0;
        top_if.tb_hsize = '0;
        top_if.tb_hburst = '0;
        top_if.tb_htrans = '0;
        top_if.tb_hmastlock = 1'b0;
        
        // Wait for reset
        @(posedge ext_rst_n);
        @(posedge ext_clk);
        @(posedge ext_clk);
        
        $display("S3 Scaffold Testbench: aft_top elaborated and simulating successfully.");
        $finish;
    end

endmodule
