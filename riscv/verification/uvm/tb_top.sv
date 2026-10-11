`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

module tb_top;

    logic HCLK;
    logic nRST;

    // TODO: Instantiate Interfaces

    // TODO: Instantiate DUT
    
    initial begin
        HCLK = 0;
        forever #5 HCLK = ~HCLK;
    end

    initial begin
        nRST = 0;
        #20 nRST = 1;
    end

    initial begin
        // run_test();
    end

endmodule
