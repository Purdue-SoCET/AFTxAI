class base_test extends uvm_test;
    `uvm_component_utils(base_test)
    
    apb_env env;
    apb_env_cfg env_cfg;
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env_cfg = apb_env_cfg::type_id::create("env_cfg");
        env_cfg.num_masters = 1;
        env_cfg.num_slaves = 2;
        
        env_cfg.base_addrs = new[2];
        env_cfg.sizes = new[2];
        env_cfg.base_addrs[0] = 32'h8000_0000; env_cfg.sizes[0] = 32'h0001_0000;
        env_cfg.base_addrs[1] = 32'h8001_0000; env_cfg.sizes[1] = 32'h0001_0000;
        
        env_cfg.m_cfg = new[1];
        env_cfg.m_cfg[0] = apb_agent_cfg::type_id::create("m_cfg");
        env_cfg.m_cfg[0].is_active = UVM_ACTIVE;
        env_cfg.m_cfg[0].mode = 0;
        if(!uvm_config_db#(virtual apb_if)::get(this, "", "vif_m", env_cfg.m_cfg[0].vif))
            `uvm_fatal("NOVIF", "Master VIF not found")
            
        env_cfg.s_cfg = new[2];
        foreach(env_cfg.s_cfg[i]) begin
            env_cfg.s_cfg[i] = apb_agent_cfg::type_id::create($sformatf("s_cfg_%0d", i));
            env_cfg.s_cfg[i].is_active = UVM_ACTIVE;
            env_cfg.s_cfg[i].mode = 1;
            env_cfg.s_cfg[i].slave_id = i;
            if(!uvm_config_db#(virtual apb_if)::get(this, "", $sformatf("vif_s%0d", i), env_cfg.s_cfg[i].vif))
                `uvm_fatal("NOVIF", "Slave VIF not found")
        end
        
        uvm_config_db#(apb_env_cfg)::set(this, "*", "cfg", env_cfg);
        env = apb_env::type_id::create("env", this);
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        apb_slave_resp_seq s_seq0, s_seq1;
        
        phase.raise_objection(this);
        s_seq0 = apb_slave_resp_seq::type_id::create("s_seq0");
        s_seq1 = apb_slave_resp_seq::type_id::create("s_seq1");
        
        fork
            s_seq0.start(env.slave_agent[0].sqr);
            s_seq1.start(env.slave_agent[1].sqr);
        join_none
        
        run_stimulus();
        
        #1000;
        phase.drop_objection(this);
    endtask
    
    virtual task run_stimulus();
    endtask
endclass
