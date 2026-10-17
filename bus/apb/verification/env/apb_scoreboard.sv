class apb_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(apb_scoreboard)
    
    uvm_analysis_export #(apb_item) master_export;
    uvm_analysis_export #(apb_item) slave_exports[];
    
    uvm_tlm_analysis_fifo #(apb_item) master_fifo;
    uvm_tlm_analysis_fifo #(apb_item) slave_fifos[];
    
    apb_env_cfg cfg;
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(apb_env_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("NO_CFG", "Could not get env cfg")
            
        master_export = new("master_export", this);
        master_fifo = new("master_fifo", this);
        
        slave_exports = new[cfg.num_slaves];
        slave_fifos = new[cfg.num_slaves];
        foreach(slave_exports[i]) begin
            slave_exports[i] = new($sformatf("slave_export_%0d", i), this);
            slave_fifos[i] = new($sformatf("slave_fifo_%0d", i), this);
        end
    endfunction
    
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        master_export.connect(master_fifo.analysis_export);
        foreach(slave_exports[i])
            slave_exports[i].connect(slave_fifos[i].analysis_export);
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        apb_item m_item, s_item;
        int slave_idx;
        forever begin
            master_fifo.get(m_item);
            slave_idx = cfg.decode(m_item.addr);
            
            if (slave_idx == -1) begin
                if (m_item.slverr != 1) 
                    `uvm_error("SCB_ERR", $sformatf("Unmapped addr %0h did not get slverr", m_item.addr))
            end else begin
                slave_fifos[slave_idx].get(s_item);
                if (m_item.addr != s_item.addr) `uvm_error("SCB_ERR", "Address mismatch")
                if (m_item.rdata != s_item.rdata) `uvm_error("SCB_ERR", "RDATA mismatch")
                if (m_item.wdata != s_item.wdata) `uvm_error("SCB_ERR", "WDATA mismatch")
            end
        end
    endtask
    
    virtual function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        if (master_fifo.used() > 0)
            `uvm_error("SCB_CHECK", $sformatf("master_fifo has %0d unprocessed items", master_fifo.used()))
        foreach(slave_fifos[i]) begin
            if (slave_fifos[i].used() > 0)
                `uvm_error("SCB_CHECK", $sformatf("slave_fifo[%0d] has %0d unprocessed items", i, slave_fifos[i].used()))
        end
    endfunction
endclass
