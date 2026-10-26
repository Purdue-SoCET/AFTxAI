`ifndef PLIC_TEST_SV
`define PLIC_TEST_SV

class plic_base_test extends uvm_test;
    `uvm_component_utils(plic_base_test)

    plic_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = plic_env::type_id::create("env", this);
    endfunction
    
    virtual function void end_of_elaboration_phase(uvm_phase phase);
        uvm_top.print_topology();
    endfunction
endclass

class plic_sanity_test extends plic_base_test;
    `uvm_component_utils(plic_sanity_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        plic_sanity_seq b_seq;
        irq_trigger_seq i_seq;
        
        phase.raise_objection(this);
        #30; // Wait for reset
        b_seq = plic_sanity_seq::type_id::create("b_seq");
        i_seq = irq_trigger_seq::type_id::create("i_seq");
        
        fork
            b_seq.start(env.b_agent.sequencer);
            i_seq.start(env.i_agent.sequencer);
        join
        
        phase.drop_objection(this);
    endtask
endclass

`endif