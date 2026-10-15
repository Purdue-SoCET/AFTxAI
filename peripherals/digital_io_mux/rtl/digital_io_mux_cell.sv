`include "digital_io_mux_cell_if.sv"

module digital_io_mux_cell #(
    parameter int NUM_FUNCS = 4,
    parameter int NUM_BITS  = 2
) (
    input logic pclk,
    input logic presetn,
    digital_io_mux_cell_if.mp vif
);
    logic sync_out;
    logic from_module_ff_next;
    logic output_en_ff_next;
    
    sync_2ff #(
        .WIDTH(1)
    ) u_sync (
        .pclk    (pclk),
        .presetn (presetn),
        .d       (vif.to_module_iopad),
        .q       (sync_out)
    );

    always_comb begin
        // Defaults
        from_module_ff_next = 1'b0;
        output_en_ff_next   = 1'b0;
        vif.to_module       = '0;
        
        if (vif.fsel < NUM_FUNCS) begin
            from_module_ff_next = vif.from_module[vif.fsel];
            output_en_ff_next   = vif.output_enable[vif.fsel];
            vif.to_module[vif.fsel] = sync_out;
        end
    end

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            vif.from_module_ff <= 1'b0;
            vif.output_en_ff   <= 1'b0;
        end else begin
            vif.from_module_ff <= from_module_ff_next;
            vif.output_en_ff   <= output_en_ff_next;
        end
    end

endmodule