`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import timer_uvm_pkg::*;

module timer_uvm_tb;

    logic pclk;
    logic presetn;
    logic capture_i;
    logic irq_o;

    apb4_if #(.ADDR_WIDTH(13), .DATA_WIDTH(32)) vif(pclk, presetn);

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
        .capture_i(capture_i),
        .irq_o(irq_o)
    );

    initial begin
        pclk = 0;
        forever #40 pclk = ~pclk;
    end

    initial begin
        presetn = 0;
        capture_i = 0;
        repeat(5) @(posedge pclk);
        presetn = 1;
    end

    initial begin
        uvm_config_db#(virtual apb4_if #(.ADDR_WIDTH(13), .DATA_WIDTH(32)))::set(null, "*", "vif", vif);
        run_test();
    end

endmodule
