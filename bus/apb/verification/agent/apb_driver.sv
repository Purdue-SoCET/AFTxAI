class apb_master_driver extends uvm_driver #(apb_item);
    `uvm_component_utils(apb_master_driver)
    
    apb_agent_cfg cfg;
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(apb_agent_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("NO_CFG", "Could not get cfg")
    endfunction

    virtual task run_phase(uvm_phase phase);
        cfg.vif.requester.PSEL <= 0;
        cfg.vif.requester.PENABLE <= 0;
        cfg.vif.requester.PWRITE <= 0;
        wait(cfg.vif.PRESETn);
        forever begin
            seq_item_port.get_next_item(req);
            drive_transfer(req);
            seq_item_port.item_done();
        end
    endtask
    
    virtual task drive_transfer(apb_item item);
        @(posedge cfg.vif.PCLK);
        // SETUP
        cfg.vif.requester.PADDR <= item.addr;
        cfg.vif.requester.PWRITE <= item.write;
        cfg.vif.requester.PWDATA <= item.wdata;
        cfg.vif.requester.PSTRB <= item.strb;
        cfg.vif.requester.PPROT <= item.prot;
        cfg.vif.requester.PSEL <= 1;
        cfg.vif.requester.PENABLE <= 0;
        
        @(posedge cfg.vif.PCLK);
        // ACCESS
        cfg.vif.requester.PENABLE <= 1;
        
        do begin
            @(posedge cfg.vif.PCLK);
        end while (cfg.vif.requester.PREADY !== 1'b1);
        
        item.rdata = cfg.vif.requester.PRDATA;
        item.slverr = cfg.vif.requester.PSLVERR;
        
        cfg.vif.requester.PSEL <= 0;
        cfg.vif.requester.PENABLE <= 0;
    endtask
endclass

class apb_slave_driver extends uvm_driver #(apb_item);
    `uvm_component_utils(apb_slave_driver)
    
    apb_agent_cfg cfg;
    logic [31:0] memory [logic [31:0]];
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(apb_agent_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("NO_CFG", "Could not get cfg")
    endfunction

    virtual task run_phase(uvm_phase phase);
        cfg.vif.completer.PREADY <= 1;
        cfg.vif.completer.PSLVERR <= 0;
        wait(cfg.vif.PRESETn);
        forever begin
            // Wait for SETUP
            do begin
                @(posedge cfg.vif.PCLK);
            end while (!(cfg.vif.completer.PSEL && !cfg.vif.completer.PENABLE));
            
            seq_item_port.try_next_item(req);
            
            if (!cfg.vif.completer.PWRITE) begin
                cfg.vif.completer.PRDATA <= memory.exists(cfg.vif.completer.PADDR) ? memory[cfg.vif.completer.PADDR] : 32'h0;
            end
            cfg.vif.completer.PSLVERR <= (req != null) ? req.slverr : 0;
            
            if (req != null && req.wait_states > 0) begin
                cfg.vif.completer.PREADY <= 0;
                repeat(req.wait_states) @(posedge cfg.vif.PCLK);
                cfg.vif.completer.PREADY <= 1;
            end else begin
                cfg.vif.completer.PREADY <= 1;
            end
            
            // Wait for ACCESS complete
            do begin
                @(posedge cfg.vif.PCLK);
            end while (!(cfg.vif.completer.PENABLE && cfg.vif.completer.PREADY));
            
            if (cfg.vif.completer.PWRITE) begin
                memory[cfg.vif.completer.PADDR] = cfg.vif.completer.PWDATA; // simplified for now
            end
            
            if(req != null) seq_item_port.item_done();
        end
    endtask
endclass
