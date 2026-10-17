class unmapped_test extends base_test;
    `uvm_component_utils(unmapped_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    
    virtual task run_stimulus();
        apb_unmapped_seq seq;
        seq = apb_unmapped_seq::type_id::create("seq");
        seq.start(env.master_agent[0].sqr);
    endtask
endclass
