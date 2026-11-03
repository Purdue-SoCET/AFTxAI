`ifndef I2C_IF_SV
`define I2C_IF_SV

interface i2c_if;
    logic scl_o;
    logic scl_oe;
    logic scl_i;
    logic sda_o;
    logic sda_oe;
    logic sda_i;
    logic irq;

    modport controller (
        output scl_o, scl_oe, sda_o, sda_oe, irq,
        input  scl_i, sda_i
    );

endinterface

`endif
