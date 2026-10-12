`timescale 1ns/1ps
module tb_top;
    logic HCLK;
    logic nRST;

    bus_ahbm_if ahbm_if();
    riscv_if r_if();

    riscv dut (
        .HCLK(HCLK),
        .nRST(nRST),
        .ahbm_if(ahbm_if),
        .port_unused(r_if.mp)
    );

    ahb_memory mem_inst (
        .HCLK(HCLK),
        .nRST(nRST),
        .ahbm_if(ahbm_if)
    );

    initial begin
        $display("Simulation started.");
        HCLK = 0;
        forever #5 HCLK = ~HCLK;
    end

    initial begin
        nRST = 0;
        #20 nRST = 1;
        #5000;
        $display("TIMEOUT: Simulation ran too long.");
        $finish;
    end
endmodule
