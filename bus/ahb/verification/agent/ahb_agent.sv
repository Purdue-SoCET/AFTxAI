`ifndef AHB_AGENT_SV
`define AHB_AGENT_SV

class ahb_agent extends uvm_agent;
    `uvm_component_utils(ahb_agent)

    ahb_agent_cfg cfg;
    
    ahb_sequencer sqr;
    ahb_driver    drv;
    ahb_responder rsp;
    ahb_monitor   mon;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        if (!uvm_config_db#(ahb_agent_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("NO_CFG", "Could not get ahb_agent_cfg")
            
        uvm_config_db#(ahb_agent_cfg)::set(this, "*", "cfg", cfg);

        if (cfg.is_active == UVM_ACTIVE) begin
            if (cfg.role == ahb_agent_cfg::MANAGER) begin
                sqr = ahb_sequencer::type_id::create("sqr", this);
                drv = ahb_driver::type_id::create("drv", this);
            end else begin
                rsp = ahb_responder::type_id::create("rsp", this);
            end
        end
        
        mon = ahb_monitor::type_id::create("mon", this);
    endfunction
    
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (cfg.is_active == UVM_ACTIVE) begin
            if (cfg.role == ahb_agent_cfg::MANAGER) begin
                drv.seq_item_port.connect(sqr.seq_item_export);
            end
            // Responder operates independently as a memory model
        end
    endfunction
endclass

`endif
