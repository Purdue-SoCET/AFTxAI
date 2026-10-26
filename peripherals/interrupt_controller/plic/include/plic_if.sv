`ifndef __PLIC_IF__
`define __PLIC_IF__

interface plic_if ();
    // verilator lint_off UNDRIVEN
    // verilator lint_off UNUSEDSIGNAL
    logic [31:1] irq_source; // Source 0 is hardwired to 0 internally
    logic        irq_target;
    // verilator lint_on UNUSEDSIGNAL
    // verilator lint_on UNDRIVEN

    modport plic (
        input  irq_source,
        output irq_target
    );

    modport system (
        output irq_source,
        input  irq_target
    );
endinterface

`endif
