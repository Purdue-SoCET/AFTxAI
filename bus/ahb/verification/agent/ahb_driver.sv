`ifndef AHB_DRIVER_SV
`define AHB_DRIVER_SV

class ahb_driver extends uvm_driver #(ahb_txn);
    `uvm_component_utils(ahb_driver)

    virtual ahb_if vif;
    ahb_agent_cfg cfg;

    ahb_txn data_phase_q[$];

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(ahb_agent_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("NO_CFG", "Could not get ahb_agent_cfg")
    endfunction
    
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        vif = cfg.vif;
    endfunction

    task run_phase(uvm_phase phase);
        vif.HSEL <= 0;
        vif.HTRANS <= ahb_pkg::IDLE;
        vif.HWDATA <= 0;
        wait(vif.HRESETn);
        
        fork
            addr_phase_thread();
            data_phase_thread();
        join
    endtask

    task addr_phase_thread();
        logic canceled;
        forever begin
            seq_item_port.try_next_item(req);
            if (req != null) begin
                canceled = 0;
                vif.HSEL <= 1'b1;
                vif.HTRANS <= req.trans;
                vif.HADDR <= req.addr;
                vif.HWRITE <= req.write;
                vif.HSIZE <= req.size;
                vif.HBURST <= req.burst;
                vif.HMASTLOCK <= req.lock;
                
                @(posedge vif.HCLK);
                while (vif.HREADY !== 1'b1) begin
                    if (vif.HRESP === 1'b1) begin
                        // Two-cycle ERROR response detected.
                        `uvm_info("DRV", $sformatf("Canceling txn due to ERROR. Addr=0x%0h", req.addr), UVM_LOW)
                        vif.HTRANS <= ahb_pkg::IDLE;
                        canceled = 1;
                    end
                    @(posedge vif.HCLK);
                end
                
                if (!canceled) begin
                    data_phase_q.push_back(req);
                end else begin
                    // If canceled, mark resp as ERROR so the sequence knows it failed, 
                    // or just leave it. In AHB, the previous transfer got the ERROR.
                    // But we still call item_done() to unblock the sequence.
                end
                seq_item_port.item_done();
            end else begin
                vif.HSEL <= 1'b0;
                vif.HTRANS <= ahb_pkg::IDLE;
                
                @(posedge vif.HCLK);
                while (vif.HREADY !== 1'b1) begin
                    if (vif.HRESP === 1'b1) begin
                        vif.HTRANS <= ahb_pkg::IDLE;
                    end
                    @(posedge vif.HCLK);
                end
            end
        end
    endtask

    task data_phase_thread();
        ahb_txn curr_txn;
        forever begin
            wait(data_phase_q.size() > 0);
            curr_txn = data_phase_q.pop_front();
            
            if (curr_txn.write && (curr_txn.trans == ahb_pkg::NONSEQ || curr_txn.trans == ahb_pkg::SEQ)) begin
                vif.HWDATA <= curr_txn.wdata;
            end
            
            @(posedge vif.HCLK);
            while (vif.HREADY !== 1'b1) begin
                @(posedge vif.HCLK);
            end
            
            if (!curr_txn.write && (curr_txn.trans == ahb_pkg::NONSEQ || curr_txn.trans == ahb_pkg::SEQ)) begin
                curr_txn.rdata = vif.HRDATA;
            end
            curr_txn.resp = vif.HRESP;
        end
    endtask
endclass

`endif
