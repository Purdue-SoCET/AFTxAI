`ifndef AHB_AGENT_CFG_SV
`define AHB_AGENT_CFG_SV

class ahb_agent_cfg extends uvm_object;
    uvm_active_passive_enum is_active = UVM_ACTIVE;
    
    typedef enum {MANAGER, SUBORDINATE} role_e;
    role_e role = MANAGER;
    
    int port_id;
    
    // Knobs for wait states and errors (used mainly by subordinate responder)
    int max_wait_states = 0;
    int error_prob = 0; // percentage
    
    virtual ahb_if vif;
    
    `uvm_object_utils_begin(ahb_agent_cfg)
        `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)
        `uvm_field_enum(role_e, role, UVM_ALL_ON)
        `uvm_field_int(port_id, UVM_ALL_ON)
        `uvm_field_int(max_wait_states, UVM_ALL_ON)
        `uvm_field_int(error_prob, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "ahb_agent_cfg");
        super.new(name);
    endfunction
endclass

`endif
