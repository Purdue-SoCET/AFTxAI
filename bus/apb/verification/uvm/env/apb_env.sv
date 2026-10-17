class apb_env extends uvm_env;
    `uvm_component_utils(apb_env)
    
    apb_env_cfg cfg;
    apb_agent master_agent[];
    apb_agent slave_agent[];
    apb_scoreboard scb;
    apb_coverage cov;
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(apb_env_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("NO_CFG", "Could not get env cfg")
            
        master_agent = new[cfg.num_masters];
        foreach(master_agent[i]) begin
            uvm_config_db#(apb_agent_cfg)::set(this, $sformatf("master_agent_%0d*", i), "cfg", cfg.m_cfg[i]);
            master_agent[i] = apb_agent::type_id::create($sformatf("master_agent_%0d", i), this);
        end
        
        slave_agent = new[cfg.num_slaves];
        foreach(slave_agent[i]) begin
            uvm_config_db#(apb_agent_cfg)::set(this, $sformatf("slave_agent_%0d*", i), "cfg", cfg.s_cfg[i]);
            slave_agent[i] = apb_agent::type_id::create($sformatf("slave_agent_%0d", i), this);
        end
        
        scb = apb_scoreboard::type_id::create("scb", this);
        cov = apb_coverage::type_id::create("cov", this);
    endfunction
    
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // Assuming 1 master for this example's connection
        master_agent[0].mon.ap.connect(scb.master_export);
        master_agent[0].mon.ap.connect(cov.analysis_export);
        foreach(slave_agent[i]) begin
            slave_agent[i].mon.ap.connect(scb.slave_exports[i]);
        end
    endfunction
endclass
