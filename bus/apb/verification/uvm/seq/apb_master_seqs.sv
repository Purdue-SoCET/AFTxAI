class apb_base_seq extends uvm_sequence #(apb_item);
    `uvm_object_utils(apb_base_seq)
    function new(string name = "apb_base_seq");
        super.new(name);
    endfunction
endclass

class apb_sanity_seq extends apb_base_seq;
    `uvm_object_utils(apb_sanity_seq)
    function new(string name="apb_sanity_seq"); super.new(name); endfunction
    
    virtual task body();
        `uvm_do_with(req, {addr == 32'h8000_0000; write == 1;})
        `uvm_do_with(req, {addr == 32'h8000_0000; write == 0;})
        `uvm_do_with(req, {addr == 32'h8001_0000; write == 1;})
        `uvm_do_with(req, {addr == 32'h8001_0000; write == 0;})
    endtask
endclass

class apb_unmapped_seq extends apb_base_seq;
    `uvm_object_utils(apb_unmapped_seq)
    function new(string name="apb_unmapped_seq"); super.new(name); endfunction
    
    virtual task body();
        `uvm_do_with(req, {addr == 32'h9000_0000;})
    endtask
endclass

class apb_random_seq extends apb_base_seq;
    `uvm_object_utils(apb_random_seq)
    function new(string name="apb_random_seq"); super.new(name); endfunction
    
    virtual task body();
        repeat(50) begin
            `uvm_do_with(req, {addr inside {[32'h8000_0000:32'h8001_FFFF], [32'h8002_0000:32'h8002_FFFF]};})
        end
    endtask
endclass

class apb_boundary_seq extends apb_base_seq;
    `uvm_object_utils(apb_boundary_seq)
    function new(string name="apb_boundary_seq"); super.new(name); endfunction
    
    virtual task body();
        // Lower and upper boundaries for S0
        `uvm_do_with(req, {addr == 32'h8000_0000;})
        `uvm_do_with(req, {addr == 32'h8000_FFFC;})
        // Lower and upper boundaries for S1
        `uvm_do_with(req, {addr == 32'h8001_0000;})
        `uvm_do_with(req, {addr == 32'h8001_FFFC;})
        // Unmapped boundaries
        `uvm_do_with(req, {addr == 32'h8002_0000;})
        `uvm_do_with(req, {addr == 32'hFFFF_FFFC;})
    endtask
endclass

class apb_b2b_seq extends apb_base_seq;
    `uvm_object_utils(apb_b2b_seq)
    function new(string name="apb_b2b_seq"); super.new(name); endfunction
    
    virtual task body();
        repeat(20) begin
            `uvm_do_with(req, {addr inside {32'h8000_0000, 32'h8001_0000, 32'h9000_0000};})
        end
    endtask
endclass
