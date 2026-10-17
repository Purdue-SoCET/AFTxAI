class apb_env_cfg extends uvm_object;
    int num_masters = 1;
    int num_slaves = 2;
    apb_agent_cfg m_cfg[];
    apb_agent_cfg s_cfg[];
    
    logic [31:0] base_addrs[];
    logic [31:0] sizes[];
    
    `uvm_object_utils(apb_env_cfg)
    
    function new(string name = "apb_env_cfg");
        super.new(name);
    endfunction
    
    function int decode(logic [31:0] addr);
        foreach(base_addrs[i]) begin
            if (addr >= base_addrs[i] && addr < base_addrs[i] + sizes[i]) return i;
        end
        return -1;
    endfunction
endclass
