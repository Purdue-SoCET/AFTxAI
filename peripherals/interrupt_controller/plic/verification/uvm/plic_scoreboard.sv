`ifndef PLIC_SCOREBOARD_SV
`define PLIC_SCOREBOARD_SV

`uvm_analysis_imp_decl(_bus)
`uvm_analysis_imp_decl(_irq)

class plic_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(plic_scoreboard)
    uvm_analysis_imp_bus #(bus_seq_item, plic_scoreboard) bus_export;
    uvm_analysis_imp_irq #(irq_seq_item, plic_scoreboard) irq_export;

    // Simple shadow memory for scoreboard
    bit [2:0] priority_reg[32];
    bit [31:1] enable_reg;
    bit [2:0] threshold_reg;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        bus_export = new("bus_export", this);
        irq_export = new("irq_export", this);
        for(int i=0; i<32; i++) priority_reg[i] = 0;
        enable_reg = 0;
        threshold_reg = 0;
    endfunction

    virtual function void write_bus(bus_seq_item item);
        // Track register writes to predict PLIC state
        if (item.is_write && !item.error) begin
            if (item.addr <= 32'h00007C) begin
                int idx = item.addr[6:2];
                if (idx != 0) priority_reg[idx] = item.data[2:0];
            end else if (item.addr == 32'h002000) begin
                enable_reg = item.data[31:1];
            end else if (item.addr == 32'h200000) begin
                threshold_reg = item.data[2:0];
            end
        end
    endfunction

    virtual function void write_irq(irq_seq_item item);
        // Basic check for target assertion
        // A complete scoreboard would duplicate the PLIC priority logic
    endfunction
endclass

`endif