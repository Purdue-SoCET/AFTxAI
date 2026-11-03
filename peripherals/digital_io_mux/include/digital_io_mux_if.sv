`ifndef DIGITAL_IO_MUX_IF_SV
`define DIGITAL_IO_MUX_IF_SV

interface digital_io_mux_if #(
    parameter int NUM_PINS  = 32,
    parameter int NUM_FUNCS = 4
);
    logic [(NUM_PINS*NUM_FUNCS)-1:0] from_module;
    logic [(NUM_PINS*NUM_FUNCS)-1:0] output_enable;
    logic [NUM_PINS-1:0]             to_module_iopad;
    logic [NUM_PINS-1:0]             from_module_ff;
    logic [NUM_PINS-1:0]             output_en_ff;
    logic [(NUM_PINS*NUM_FUNCS)-1:0] to_module;

    modport top (
        input  from_module, output_enable, to_module_iopad,
        output from_module_ff, output_en_ff, to_module
    );
endinterface

`endif