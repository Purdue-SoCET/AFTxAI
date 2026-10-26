module lint_top;
    logic clk, nrst;
    
    // verilator lint_off UNUSED
    // verilator lint_off UNDRIVEN
    bus_protocol_if bus();
    plic_if irq_if();
    // verilator lint_on UNDRIVEN
    // verilator lint_on UNUSED

    plic u_plic (
        .clk(clk),
        .nrst(nrst),
        .bus(bus.peripheral_vital),
        .irq_if(irq_if.plic)
    );
endmodule