package plic_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "plic_bus_agent.sv"
    `include "plic_irq_agent.sv"
    `include "plic_scoreboard.sv"
    `include "plic_env.sv"
    `include "plic_seqs.sv"
    `include "plic_test.sv"
endpackage