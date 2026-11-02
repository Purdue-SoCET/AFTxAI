class apb_agent extends uvm_agent;
    `uvm_component_utils(apb_agent)
    
    apb_agent_cfg cfg;
    uvm_sequencer #(apb_item) sqr;
    uvm_driver #(apb_item) drv;
    apb_monitor mon;
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(apb_agent_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("NO_CFG", "Could not get cfg")
            
        mon = apb_monitor::type_id::create("mon", this);
        if (cfg.is_active == UVM_ACTIVE) begin
            sqr = uvm_sequencer#(apb_item)::type_id::create("sqr", this);
            if (cfg.mode == 0) // Master
                drv = apb_master_driver::type_id::create("drv", this);
            else // Slave
                drv = apb_slave_driver::type_id::create("drv", this);
        end
    endfunction
    
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (cfg.is_active == UVM_ACTIVE) begin
            drv.seq_item_port.connect(sqr.seq_item_export);
        end
    endfunction
endclass
