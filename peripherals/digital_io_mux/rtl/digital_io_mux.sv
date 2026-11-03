`include "apb_if.sv"
`include "digital_io_mux_if.sv"
`include "digital_io_mux_cell_if.sv"

module digital_io_mux #(
    parameter int NUM_PINS = 32,
    parameter int NUM_FUNCS = 4,
    parameter int NUM_BITS = 2,
    parameter int NUM_REGS = 2
) (
    input logic pclk,
    input logic presetn,
    apb_if.completer apb,
    digital_io_mux_if.top vif
);

    // [IOMUX-PAR-001] Elaboration checks
    if (NUM_PINS < 1 || NUM_PINS > 32) $error("NUM_PINS out of range");
    if (NUM_FUNCS < 1 || NUM_FUNCS > 4) $error("NUM_FUNCS out of range");
    if (NUM_BITS < 1 || NUM_BITS > 2) $error("NUM_BITS out of range");
    if (NUM_REGS < 1 || NUM_REGS > 2) $error("NUM_REGS out of range");
    if (NUM_FUNCS > (1 << NUM_BITS)) $error("NUM_FUNCS > 2**NUM_BITS");
    if ((NUM_PINS * NUM_BITS) > (NUM_REGS * 32)) $error("NUM_PINS*NUM_BITS > NUM_REGS*32");

    logic [(NUM_REGS*32)-1:0] fsel_out;

    digital_io_mux_apb #(
        .NUM_PINS(NUM_PINS),
        .NUM_BITS(NUM_BITS),
        .NUM_REGS(NUM_REGS)
    ) u_apb (
        .pclk(pclk),
        .presetn(presetn),
        .apb(apb),
        .fsel_out(fsel_out)
    );

    genvar i;
    generate
        for (i = 0; i < NUM_PINS; i++) begin : gen_cells
            digital_io_mux_cell_if #(
                .NUM_FUNCS(NUM_FUNCS),
                .NUM_BITS(NUM_BITS)
            ) cell_vif ();

            // Connect top level signals to cell interface
            assign cell_vif.fsel = fsel_out[(i * NUM_BITS) +: NUM_BITS];
            
            assign cell_vif.from_module     = vif.from_module[(i * NUM_FUNCS) +: NUM_FUNCS];
            assign cell_vif.output_enable   = vif.output_enable[(i * NUM_FUNCS) +: NUM_FUNCS];
            assign cell_vif.to_module_iopad = vif.to_module_iopad[i];
            
            assign vif.from_module_ff[i] = cell_vif.from_module_ff;
            assign vif.output_en_ff[i]   = cell_vif.output_en_ff;
            assign vif.to_module[(i * NUM_FUNCS) +: NUM_FUNCS] = cell_vif.to_module;
            
            digital_io_mux_cell #(
                .NUM_FUNCS(NUM_FUNCS),
                .NUM_BITS(NUM_BITS)
            ) u_cell (
                .pclk(pclk),
                .presetn(presetn),
                .vif(cell_vif.mp)
            );
        end
    endgenerate

endmodule