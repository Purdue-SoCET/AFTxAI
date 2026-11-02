`ifndef AHB_ENV_SV
`define AHB_ENV_SV

class ahb_env extends uvm_env;
    `uvm_component_utils(ahb_env)

    ahb_env_cfg cfg;

    ahb_agent mgr_agents[];
    ahb_agent sub_agents[];
    ahb_scoreboard scb;
    ahb_virtual_sequencer vsqr;
    ahb_coverage cov;

    function new(string name = "ahb_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        if (!uvm_config_db#(ahb_env_cfg)::get(this, "", "cfg", cfg)) begin
            `uvm_fatal("NOCFG", "ahb_env_cfg not found in uvm_config_db")
        end

        // Create virtual sequencer
        vsqr = ahb_virtual_sequencer::type_id::create("vsqr", this);
        vsqr.cfg = cfg;

        // Create Manager Agents
        mgr_agents = new[cfg.num_managers];
        foreach (mgr_agents[i]) begin
            uvm_config_db#(ahb_agent_cfg)::set(this, $sformatf("mgr_agent_%0d", i), "cfg", cfg.mgr_cfgs[i]);
            mgr_agents[i] = ahb_agent::type_id::create($sformatf("mgr_agent_%0d", i), this);
        end

        // Create Subordinate Agents
        sub_agents = new[cfg.num_subordinates];
        foreach (sub_agents[i]) begin
            uvm_config_db#(ahb_agent_cfg)::set(this, $sformatf("sub_agent_%0d", i), "cfg", cfg.sub_cfgs[i]);
            sub_agents[i] = ahb_agent::type_id::create($sformatf("sub_agent_%0d", i), this);
        end

        // Create Scoreboard
        scb = ahb_scoreboard::type_id::create("scb", this);
        uvm_config_db#(ahb_env_cfg)::set(this, "scb", "cfg", cfg);

        // Create Coverage
        cov = ahb_coverage::type_id::create("cov", this);
        uvm_config_db#(ahb_env_cfg)::set(this, "cov", "cfg", cfg);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        // Connect Manager Agent monitors to Scoreboard, Coverage, and sequencers to Virtual Sequencer
        vsqr.mgr_sqrs = new[cfg.num_managers];
        foreach (mgr_agents[i]) begin
            mgr_agents[i].mon.item_collected_port.connect(scb.mgr_fifos[i].analysis_export);
            mgr_agents[i].mon.item_collected_port.connect(cov.analysis_export);
            if (cfg.mgr_cfgs[i].is_active == UVM_ACTIVE) begin
                vsqr.mgr_sqrs[i] = mgr_agents[i].sqr;
            end
        end

        // Connect Subordinate Agent monitors to Scoreboard (No active sequencer for subordinate responder, usually)
        foreach (sub_agents[i]) begin
            sub_agents[i].mon.item_collected_port.connect(scb.sub_fifos[i].analysis_export);
            // If subordinate has a sequencer for some reason, we could connect it here, but generally they just respond.
        end
    endfunction
endclass

`endif
