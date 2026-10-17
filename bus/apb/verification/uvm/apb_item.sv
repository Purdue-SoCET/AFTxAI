class apb_item extends uvm_sequence_item;
    rand logic [31:0] addr;
    rand logic        write;
    rand logic [31:0] wdata;
    logic [31:0]      rdata;
    rand logic [3:0]  strb;
    rand logic [2:0]  prot;
    rand logic        slverr;
    rand int          wait_states;

    `uvm_object_utils_begin(apb_item)
        `uvm_field_int(addr, UVM_ALL_ON)
        `uvm_field_int(write, UVM_ALL_ON)
        `uvm_field_int(wdata, UVM_ALL_ON)
        `uvm_field_int(rdata, UVM_ALL_ON)
        `uvm_field_int(strb, UVM_ALL_ON)
        `uvm_field_int(prot, UVM_ALL_ON)
        `uvm_field_int(slverr, UVM_ALL_ON)
        `uvm_field_int(wait_states, UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_object_utils_end

    constraint c_wait_states {
        wait_states dist {0 := 80, [1:5] := 20};
    }
    
    constraint c_align {
        addr[1:0] == 2'b00;
    }

    function new(string name = "apb_item");
        super.new(name);
    endfunction
endclass
