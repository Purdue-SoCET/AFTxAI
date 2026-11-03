module lint_top (
    input logic PCLK,
    input logic PRESETn
);
    /* verilator lint_off UNUSED */
    /* verilator lint_off UNDRIVEN */
    apb_if apb(.PCLK(PCLK), .PRESETn(PRESETn));
    i2c_if i2c_pins();
    /* verilator lint_on UNUSED */
    /* verilator lint_on UNDRIVEN */
    
    i2c i2c_inst (
        .apb(apb.completer),
        .i2c_pins(i2c_pins.controller)
    );
endmodule
