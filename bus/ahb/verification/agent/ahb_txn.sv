`ifndef AHB_TXN_SV
`define AHB_TXN_SV

class ahb_txn extends uvm_sequence_item;
    rand logic [31:0] addr;
    rand logic write;
    rand ahb_pkg::HSIZE_t size;
    rand ahb_pkg::HBURST_t burst;
    rand ahb_pkg::HTRANS_t trans;
    rand logic lock;
    rand logic [31:0] wdata;
    logic [31:0] rdata;
    logic resp; // 0: OKAY, 1: ERROR
    int port_id;

    `uvm_object_utils_begin(ahb_txn)
        `uvm_field_int(addr, UVM_ALL_ON)
        `uvm_field_int(write, UVM_ALL_ON)
        `uvm_field_enum(ahb_pkg::HSIZE_t, size, UVM_ALL_ON)
        `uvm_field_enum(ahb_pkg::HBURST_t, burst, UVM_ALL_ON)
        `uvm_field_enum(ahb_pkg::HTRANS_t, trans, UVM_ALL_ON)
        `uvm_field_int(lock, UVM_ALL_ON)
        `uvm_field_int(wdata, UVM_ALL_ON)
        `uvm_field_int(rdata, UVM_ALL_ON)
        `uvm_field_int(resp, UVM_ALL_ON)
        `uvm_field_int(port_id, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "ahb_txn");
        super.new(name);
    endfunction
endclass

`endif
