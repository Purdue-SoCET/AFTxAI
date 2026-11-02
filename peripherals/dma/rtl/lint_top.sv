/* verilator lint_off UNUSEDSIGNAL */
/* verilator lint_off UNDRIVEN */
/* verilator lint_off UNUSEDPARAM */
/* verilator lint_off UNUSEDSIGNAL */
/* verilator lint_off UNDRIVEN */
/* verilator lint_off UNUSEDPARAM */
/* verilator lint_off EOFNEWLINE */
`timescale 1ns/1ps

module lint_top (
    input logic clk,
    input logic rst_n,
    input logic drq,
    output logic daq,
    output logic irq
);
    apb_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) reg_bus(.pclk(clk), .presetn(rst_n));
    ahb_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) mem_bus(.HCLK(clk), .HRESETn(rst_n));
    
    dma_controller i_dma_controller (
        .clk(clk),
        .rst_n(rst_n),
        .drq(drq),
        .daq(daq),
        .irq(irq),
        .reg_bus(reg_bus.completer),
        .mem_bus(mem_bus.manager)
    );
endmodule
