`ifndef UART_IF_SV
`define UART_IF_SV

/* verilator lint_off UNUSEDSIGNAL */
/* verilator lint_off UNDRIVEN */
// Reason: Signals in interfaces are driven/used by connected modules, not necessarily within the interface itself.

interface uart_if;
    logic tx;
    logic rx;
    logic rts_n;
    logic cts_n;
    logic irq;

    modport port(
        output tx, rts_n, irq,
        input  rx, cts_n
    );
endinterface

`endif
