`timescale 1ns/1ps

import uvm_pkg::*;
import plic_uvm_pkg::*;
`include "uvm_macros.svh"

// Simple clock interface
interface clk_if;
    logic clk;
    logic nrst;
endinterface

module tb_uvm_top;

    clk_if cif();
    bus_protocol_if bus();
    plic_if irq_if();

    // Clock and Reset Generation
    initial begin
        cif.clk = 0;
        forever #5 cif.clk = ~cif.clk;
    end

    initial begin
        cif.nrst = 0;
        #20 cif.nrst = 1;
    end

    // DUT Instantiation
    plic u_plic (
        .clk(cif.clk),
        .nrst(cif.nrst),
        .bus(bus.peripheral_vital),
        .irq_if(irq_if.plic)
    );

    initial begin
        uvm_config_db#(virtual bus_protocol_if)::set(null, "*", "vif", bus);
        uvm_config_db#(virtual plic_if)::set(null, "*", "vif", irq_if);
        uvm_config_db#(virtual clk_if)::set(null, "*", "clk_vif", cif);

        run_test("plic_sanity_test");
    end

endmodule