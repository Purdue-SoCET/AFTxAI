module i2c #(
    parameter logic [31:0] BASE_ADDR = 32'h8000_5000,
    parameter int NWORDS = 6
) (
    apb_if.completer apb,
    i2c_if.controller i2c_pins
);

    bus_protocol_if bus ();

    apb_completer #(
        .BASE_ADDR(BASE_ADDR),
        .NWORDS(NWORDS)
    ) apb_completer_inst (
        .apb(apb),
        .bus(bus.protocol)
    );

    logic        cmd_valid;
    logic        cmd_start;
    logic        cmd_stop;
    logic        cmd_write;
    logic        cmd_read;
    logic        cmd_nack;
    logic [7:0]  tx_data;
    logic [15:0] prescale;
    logic        enable;
    
    logic        tip;
    logic        bus_busy;
    logic        rx_nack;
    logic [7:0]  rx_data;

    i2c_regs i2c_regs_inst (
        .PCLK       (apb.PCLK),
        .PRESETn    (apb.PRESETn),
        .bus        (bus.peripheral_vital),
        .cmd_valid  (cmd_valid),
        .cmd_start  (cmd_start),
        .cmd_stop   (cmd_stop),
        .cmd_write  (cmd_write),
        .cmd_read   (cmd_read),
        .cmd_nack   (cmd_nack),
        .tx_data    (tx_data),
        .prescale   (prescale),
        .enable     (enable),
        .tip        (tip),
        .bus_busy   (bus_busy),
        .rx_nack    (rx_nack),
        .rx_data    (rx_data),
        .irq        (i2c_pins.irq)
    );

    i2c_engine i2c_engine_inst (
        .PCLK       (apb.PCLK),
        .PRESETn    (apb.PRESETn),
        .cmd_valid  (cmd_valid),
        .cmd_start  (cmd_start),
        .cmd_stop   (cmd_stop),
        .cmd_write  (cmd_write),
        .cmd_read   (cmd_read),
        .cmd_nack   (cmd_nack),
        .tx_data    (tx_data),
        .prescale   (prescale),
        .enable     (enable),
        .tip        (tip),
        .bus_busy   (bus_busy),
        .rx_nack    (rx_nack),
        .rx_data    (rx_data),
        .scl_o      (i2c_pins.scl_o),
        .scl_oe     (i2c_pins.scl_oe),
        .scl_i      (i2c_pins.scl_i),
        .sda_o      (i2c_pins.sda_o),
        .sda_oe     (i2c_pins.sda_oe),
        .sda_i      (i2c_pins.sda_i)
    );

endmodule
