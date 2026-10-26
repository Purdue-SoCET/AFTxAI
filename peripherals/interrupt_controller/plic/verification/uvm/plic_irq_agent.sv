`ifndef PLIC_IRQ_AGENT_SV
`define PLIC_IRQ_AGENT_SV

class irq_seq_item extends uvm_sequence_item;
    rand bit [31:1] irq_source;
    bit             irq_target;

    `uvm_object_utils_begin(irq_seq_item)
        `uvm_field_int(irq_source, UVM_ALL_ON)
        `uvm_field_int(irq_target, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "irq_seq_item");
        super.new(name);
    endfunction
endclass

class irq_driver extends uvm_driver #(irq_seq_item);
    `uvm_component_utils(irq_driver)
    virtual plic_if vif;
    virtual clk_if  clk_vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        vif.irq_source <= '0;
        forever begin
            seq_item_port.get_next_item(req);
            @(posedge clk_vif.clk);
            vif.irq_source <= req.irq_source;
            seq_item_port.item_done();
        end
    endtask
endclass

class irq_monitor extends uvm_monitor;
    `uvm_component_utils(irq_monitor)
    virtual plic_if vif;
    virtual clk_if  clk_vif;
    uvm_analysis_port #(irq_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        irq_seq_item item;
        bit [31:1] prev_source = '0;
        bit prev_target = 0;
        forever begin
            @(posedge clk_vif.clk);
            if (vif.irq_source != prev_source || vif.irq_target != prev_target) begin
                item = irq_seq_item::type_id::create("item");
                item.irq_source = vif.irq_source;
                item.irq_target = vif.irq_target;
                ap.write(item);
                prev_source = vif.irq_source;
                prev_target = vif.irq_target;
            end
        end
    endtask
endclass

class irq_agent extends uvm_agent;
    `uvm_component_utils(irq_agent)
    irq_driver driver;
    irq_monitor monitor;
    uvm_sequencer #(irq_seq_item) sequencer;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor = irq_monitor::type_id::create("monitor", this);
        if (get_is_active() == UVM_ACTIVE) begin
            driver = irq_driver::type_id::create("driver", this);
            sequencer = uvm_sequencer#(irq_seq_item)::type_id::create("sequencer", this);
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        uvm_config_db#(virtual plic_if)::get(this, "", "vif", monitor.vif);
        uvm_config_db#(virtual clk_if)::get(this, "", "clk_vif", monitor.clk_vif);
        if (get_is_active() == UVM_ACTIVE) begin
            uvm_config_db#(virtual plic_if)::get(this, "", "vif", driver.vif);
            uvm_config_db#(virtual clk_if)::get(this, "", "clk_vif", driver.clk_vif);
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end
    endfunction
endclass

`endif