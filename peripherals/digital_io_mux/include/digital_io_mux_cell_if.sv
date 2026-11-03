`ifndef DIGITAL_IO_MUX_CELL_IF_SV
`define DIGITAL_IO_MUX_CELL_IF_SV

interface digital_io_mux_cell_if #(
    parameter int NUM_FUNCS = 4,
    parameter int NUM_BITS  = 2
);
    logic [NUM_BITS-1:0]  fsel;
    logic [NUM_FUNCS-1:0] from_module;
    logic [NUM_FUNCS-1:0] output_enable;
    logic                 to_module_iopad;
    logic                 from_module_ff;
    logic                 output_en_ff;
    logic [NUM_FUNCS-1:0] to_module;

    modport mp (
        input  fsel, from_module, output_enable, to_module_iopad,
        output from_module_ff, output_en_ff, to_module
    );
endinterface

`endif