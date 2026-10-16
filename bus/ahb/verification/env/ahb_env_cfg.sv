`ifndef AHB_ENV_CFG_SV
`define AHB_ENV_CFG_SV

class ahb_env_cfg extends uvm_object;
    int num_managers;
    int num_subordinates;
    
    ahb_agent_cfg mgr_cfgs[];
    ahb_agent_cfg sub_cfgs[];
    
    ahb_addr_map addr_map;
    
    `uvm_object_utils_begin(ahb_env_cfg)
        `uvm_field_int(num_managers, UVM_ALL_ON)
        `uvm_field_int(num_subordinates, UVM_ALL_ON)
        `uvm_field_object(addr_map, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "ahb_env_cfg");
        super.new(name);
    endfunction
endclass

`endif
