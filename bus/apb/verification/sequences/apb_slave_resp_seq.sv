class apb_slave_resp_seq extends uvm_sequence #(apb_item);
    `uvm_object_utils(apb_slave_resp_seq)
    function new(string name="apb_slave_resp_seq"); super.new(name); endfunction
    
    virtual task body();
        forever begin
            `uvm_do_with(req, {wait_states == 0; slverr == 0;})
        end
    endtask
endclass

class apb_slave_wait_seq extends apb_slave_resp_seq;
    `uvm_object_utils(apb_slave_wait_seq)
    function new(string name="apb_slave_wait_seq"); super.new(name); endfunction
    
    virtual task body();
        forever begin
            `uvm_do_with(req, {wait_states inside {[1:5]}; slverr == 0;})
        end
    endtask
endclass

class apb_slave_err_seq extends apb_slave_resp_seq;
    `uvm_object_utils(apb_slave_err_seq)
    function new(string name="apb_slave_err_seq"); super.new(name); endfunction
    
    virtual task body();
        forever begin
            `uvm_do_with(req, {wait_states inside {[0:2]}; slverr == 1;})
        end
    endtask
endclass

class apb_slave_rand_seq extends apb_slave_resp_seq;
    `uvm_object_utils(apb_slave_rand_seq)
    function new(string name="apb_slave_rand_seq"); super.new(name); endfunction
    
    virtual task body();
        forever begin
            `uvm_do_with(req, {wait_states inside {[0:5]}; slverr dist {0 := 80, 1 := 20};})
        end
    endtask
endclass
