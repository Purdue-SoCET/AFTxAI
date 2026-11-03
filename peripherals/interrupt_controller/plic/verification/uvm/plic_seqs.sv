`ifndef PLIC_SEQS_SV
`define PLIC_SEQS_SV

class bus_base_seq extends uvm_sequence #(bus_seq_item);
    `uvm_object_utils(bus_base_seq)

    function new(string name = "bus_base_seq");
        super.new(name);
    endfunction

    task write_reg(input bit [31:0] addr, input bit [31:0] data);
        bus_seq_item item = bus_seq_item::type_id::create("item");
        start_item(item);
        item.is_write = 1;
        item.addr = addr;
        item.data = data;
        finish_item(item);
    endtask

    task read_reg(input bit [31:0] addr, output bit [31:0] data);
        bus_seq_item item = bus_seq_item::type_id::create("item");
        start_item(item);
        item.is_write = 0;
        item.addr = addr;
        finish_item(item);
        data = item.rdata;
    endtask
endclass

class plic_sanity_seq extends bus_base_seq;
    `uvm_object_utils(plic_sanity_seq)
    function new(string name="plic_sanity_seq"); super.new(name); endfunction

    virtual task body();
        bit [31:0] rdata;
        // T01: Reset and Priority[0] read/write
        read_reg(32'h000000, rdata);
        if(rdata !== 0) `uvm_error("SEQ", "PRIORITY[0] != 0 on reset");
        write_reg(32'h000000, 32'h7);
        read_reg(32'h000000, rdata);
        if(rdata !== 0) `uvm_error("SEQ", "PRIORITY[0] write was not ignored");

        // Set PRIORITY[1]=7, ENABLE[1]=1, THRESHOLD=0
        write_reg(32'h000004, 32'h7);
        write_reg(32'h002000, 32'h2);
        write_reg(32'h200000, 32'h0);
        
        // IRQ trigger logic would be driven by irq_agent sequence, but for simplicity
        // we assume the top level or another sequence fires IRQ 1 here
        #50;
        
        // Read CLAIM
        read_reg(32'h200004, rdata);
        if(rdata == 1) `uvm_info("SEQ", "Claimed IRQ 1", UVM_LOW)
        else `uvm_error("SEQ", $sformatf("Failed to claim IRQ 1, got %0d", rdata));

        // Complete CLAIM
        write_reg(32'h200004, 32'h1);
    endtask
endclass

class irq_trigger_seq extends uvm_sequence #(irq_seq_item);
    `uvm_object_utils(irq_trigger_seq)
    function new(string name="irq_trigger_seq"); super.new(name); endfunction

    virtual task body();
        irq_seq_item item = irq_seq_item::type_id::create("item");
        #100;
        start_item(item);
        item.irq_source = 31'b1; // Trigger IRQ 1
        finish_item(item);
        #50;
        start_item(item);
        item.irq_source = 31'b0;
        finish_item(item);
    endtask
endclass

`endif