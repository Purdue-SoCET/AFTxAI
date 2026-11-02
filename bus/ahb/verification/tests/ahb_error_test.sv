`ifndef AHB_ERROR_TEST_SV
`define AHB_ERROR_TEST_SV

class ahb_error_test extends ahb_base_test;
    `uvm_component_utils(ahb_error_test)

    function new(string name = "ahb_error_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Configure subordinates to inject ERROR responses
        foreach (env_cfg.sub_cfgs[i]) begin
            env_cfg.sub_cfgs[i].error_prob = 10; // 10% probability of an ERROR response
            env_cfg.sub_cfgs[i].max_wait_states = 2; // Also add some wait states
        end
        uvm_config_db#(ahb_env_cfg)::set(this, "env", "cfg", env_cfg);
    endfunction

    task run_phase(uvm_phase phase);
        ahb_matrix_vseq vseq;
        phase.raise_objection(this);
        
        `uvm_info("TEST", "Starting ahb_error_test...", UVM_LOW)
        vseq = ahb_matrix_vseq::type_id::create("vseq");
        // Use a reasonable number of transactions to ensure we hit the error paths
        if (!vseq.randomize() with { num_txns == 200; }) begin
            `uvm_fatal("TEST", "Failed to randomize vseq")
        end
        vseq.start(env.vsqr);
        
        phase.drop_objection(this);
    endtask
endclass

`endif
