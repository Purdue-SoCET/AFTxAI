class apb_agent_cfg extends uvm_object;
    uvm_active_passive_enum is_active = UVM_ACTIVE;
    int mode = 0; // 0: Master, 1: Slave
    virtual apb_if vif;
    int slave_id = -1; // -1 for master

    `uvm_object_utils(apb_agent_cfg)
    
    function new(string name = "apb_agent_cfg");
        super.new(name);
    endfunction
endclass
