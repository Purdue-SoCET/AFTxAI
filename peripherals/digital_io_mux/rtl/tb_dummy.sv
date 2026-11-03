`include "apb_if.sv"
`include "digital_io_mux_if.sv"
`include "digital_io_mux_cell_if.sv"

module tb_dummy;
    logic pclk;
    logic presetn;
    apb_if apb();
    digital_io_mux_if vif();

    digital_io_mux #(
        .NUM_PINS(32),
        .NUM_FUNCS(4),
        .NUM_BITS(2),
        .NUM_REGS(2)
    ) dut (
        .pclk(pclk),
        .presetn(presetn),
        .apb(apb.completer),
        .vif(vif.top)
    );
endmodule
