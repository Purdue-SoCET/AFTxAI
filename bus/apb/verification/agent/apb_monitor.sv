class apb_monitor extends uvm_monitor;
    `uvm_component_utils(apb_monitor)
    
    apb_agent_cfg cfg;
    uvm_analysis_port #(apb_item) ap;
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(apb_agent_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("NO_CFG", "Could not get cfg")
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        apb_item item;
        wait(cfg.vif.PRESETn);
        forever begin
            @(posedge cfg.vif.PCLK);
            if (cfg.vif.PSEL && cfg.vif.PENABLE && cfg.vif.PREADY) begin
                item = apb_item::type_id::create("item");
                item.addr = cfg.vif.PADDR;
                item.write = cfg.vif.PWRITE;
                item.wdata = cfg.vif.PWDATA;
                item.rdata = cfg.vif.PRDATA;
                item.strb = cfg.vif.PSTRB;
                item.prot = cfg.vif.PPROT;
                item.slverr = cfg.vif.PSLVERR;
                ap.write(item);
            end
        end
    endtask
endclass
