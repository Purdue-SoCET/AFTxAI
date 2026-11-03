`ifndef AHB_MATRIX_TEST_SV
`define AHB_MATRIX_TEST_SV

class ahb_matrix_test extends uvm_test;
    `uvm_component_utils(ahb_matrix_test)

    ahb_env env;
    ahb_env_cfg env_cfg;

    function new(string name = "ahb_matrix_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Configure Environment
        env_cfg = ahb_env_cfg::type_id::create("env_cfg");
        env_cfg.num_managers = 4;
        env_cfg.num_subordinates = 4;

        env_cfg.mgr_cfgs = new[env_cfg.num_managers];
        env_cfg.sub_cfgs = new[env_cfg.num_subordinates];

        // Address Map setup (Matches tb_uvm_top interconnect map)
        env_cfg.addr_map = ahb_addr_map::type_id::create("addr_map");
        env_cfg.addr_map.add_region(32'h0000_0000, 32'h0FFF_FFFF, 0);
        env_cfg.addr_map.add_region(32'h1000_0000, 32'h1FFF_FFFF, 1);
        env_cfg.addr_map.add_region(32'h2000_0000, 32'h2FFF_FFFF, 2);
        env_cfg.addr_map.add_region(32'h3000_0000, 32'h3FFF_FFFF, 3);

        // Manager Configs
        for (int i = 0; i < env_cfg.num_managers; i++) begin
            env_cfg.mgr_cfgs[i] = ahb_agent_cfg::type_id::create($sformatf("mgr_cfg_%0d", i));
            env_cfg.mgr_cfgs[i].is_active = UVM_ACTIVE;
            env_cfg.mgr_cfgs[i].role = ahb_agent_cfg::MANAGER;
            env_cfg.mgr_cfgs[i].port_id = i;
            if(!uvm_config_db#(virtual ahb_if)::get(this, $sformatf("env.mgr_agent_%0d", i), "vif", env_cfg.mgr_cfgs[i].vif))
                `uvm_fatal("NOVIF", $sformatf("Virtual interface not found for mgr_agent_%0d", i))
        end

        // Subordinate Configs
        for (int i = 0; i < env_cfg.num_subordinates; i++) begin
            env_cfg.sub_cfgs[i] = ahb_agent_cfg::type_id::create($sformatf("sub_cfg_%0d", i));
            env_cfg.sub_cfgs[i].is_active = UVM_ACTIVE;
            env_cfg.sub_cfgs[i].role = ahb_agent_cfg::SUBORDINATE;
            env_cfg.sub_cfgs[i].port_id = i;
            if(!uvm_config_db#(virtual ahb_if)::get(this, $sformatf("env.sub_agent_%0d", i), "vif", env_cfg.sub_cfgs[i].vif))
                `uvm_fatal("NOVIF", $sformatf("Virtual interface not found for sub_agent_%0d", i))
        end

        uvm_config_db#(ahb_env_cfg)::set(this, "env*", "cfg", env_cfg);

        // Create Environment
        env = ahb_env::type_id::create("env", this);
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        ahb_matrix_vseq vseq;
        super.run_phase(phase);
        phase.raise_objection(this);
        
        vseq = ahb_matrix_vseq::type_id::create("vseq");
        if (!vseq.randomize()) `uvm_error("TEST", "Failed to randomize vseq")
        vseq.start(env.vsqr);
        
        #100;
        
        phase.drop_objection(this);
    endtask

endclass

`endif