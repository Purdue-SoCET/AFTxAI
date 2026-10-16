`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import timer_uvm_pkg::*;

interface timer_sb_if(input logic clk, input logic rst_n);
    logic capture_i;
    logic irq_o;
endinterface

module timer_uvm_tb;

    logic pclk;
    logic presetn;

    apb4_if #(.ADDR_WIDTH(13), .DATA_WIDTH(32)) vif(pclk, presetn);
    timer_sb_if sb_vif(pclk, presetn);

    timer_apb dut (
        .pclk(vif.pclk),
        .presetn(vif.presetn),
        .paddr(vif.paddr),
        .psel(vif.psel),
        .penable(vif.penable),
        .pwrite(vif.pwrite),
        .pwdata(vif.pwdata),
        .pstrb(vif.pstrb),
        .pprot(vif.pprot),
        .prdata(vif.prdata),
        .pready(vif.pready),
        .pslverr(vif.pslverr),
        .capture_i(sb_vif.capture_i),
        .irq_o(sb_vif.irq_o)
    );

    initial begin
        pclk = 0;
        forever #40 pclk = ~pclk;
    end

    initial begin
        presetn = 0;
        sb_vif.capture_i = 0;
        repeat(5) @(posedge pclk);
        presetn = 1;
    end

    initial begin
        uvm_config_db#(virtual apb4_if #(.ADDR_WIDTH(13), .DATA_WIDTH(32)))::set(null, "*", "vif", vif);
        uvm_config_db#(virtual timer_sb_if)::set(null, "*", "sb_vif", sb_vif);
        run_test();
    end

endmodule
