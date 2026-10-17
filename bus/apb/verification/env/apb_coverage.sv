class apb_coverage extends uvm_subscriber #(apb_item);
    `uvm_component_utils(apb_coverage)
    
    apb_item item;
    apb_env_cfg cfg;
    
    covergroup cg_apb;
        option.per_instance = 1;
        cp_addr: coverpoint item.addr {
            bins lower = {32'h8000_0000};
            bins upper = {32'h8001_FFFC}; // word-aligned max address
            bins unmapped = {[32'h8002_0000 : 32'hFFFF_FFFF]};
            bins others = default;
        }
        cp_write: coverpoint item.write;
        cp_slverr: coverpoint item.slverr;
        cp_slave_idx: coverpoint cfg.decode(item.addr) {
            bins s0 = {0};
            bins s1 = {1};
            bins unmapped = {-1};
        }
        
        cross cp_slave_idx, cp_write, cp_slverr;
    endgroup
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_apb = new();
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(apb_env_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("NO_CFG", "Could not get env cfg")
    endfunction
    
    virtual function void write(apb_item t);
        item = t;
        cg_apb.sample();
    endfunction
endclass
