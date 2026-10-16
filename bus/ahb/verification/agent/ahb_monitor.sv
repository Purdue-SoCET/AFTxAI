`ifndef AHB_MONITOR_SV
`define AHB_MONITOR_SV

class ahb_monitor extends uvm_monitor;
    `uvm_component_utils(ahb_monitor)

    virtual ahb_if vif;
    ahb_agent_cfg cfg;
    
    uvm_analysis_port #(ahb_txn) item_collected_port;
    
    ahb_txn data_phase_q[$];

    function new(string name, uvm_component parent);
        super.new(name, parent);
        item_collected_port = new("item_collected_port", this);
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
        wait(vif.HRESETn);
        fork
            monitor_addr_phase();
            monitor_data_phase();
        join
    endtask

    task monitor_addr_phase();
        ahb_txn txn;
        forever begin
            @(posedge vif.HCLK);
            #1ps; // Wait for NBA assignments from drivers to settle
            if (vif.HREADY === 1'b1 && vif.HSEL === 1'b1) begin
                if (vif.HTRANS === ahb_pkg::NONSEQ || vif.HTRANS === ahb_pkg::SEQ) begin
                    `uvm_info("MON", $sformatf("Captured addr phase: Addr=0x%0h, Port=%0d", vif.HADDR, cfg.port_id), UVM_LOW)
                    txn = ahb_txn::type_id::create("txn");
                    txn.addr = vif.HADDR;
                    txn.write = vif.HWRITE;
                    txn.size = ahb_pkg::HSIZE_t'(vif.HSIZE);
                    txn.burst = ahb_pkg::HBURST_t'(vif.HBURST);
                    txn.trans = ahb_pkg::HTRANS_t'(vif.HTRANS);
                    txn.lock = vif.HMASTLOCK;
                    txn.port_id = cfg.port_id;
                    
                    data_phase_q.push_back(txn);
                end
            end
        end
    endtask

    task monitor_data_phase();
        ahb_txn curr_txn;
        forever begin
            wait(data_phase_q.size() > 0);
            curr_txn = data_phase_q.pop_front();
            
            @(posedge vif.HCLK);
            while (vif.HREADY !== 1'b1) begin
                @(posedge vif.HCLK);
            end
            #1ps; // Wait for NBA assignments to settle
            
            if (curr_txn.write) begin
                curr_txn.wdata = vif.HWDATA;
            end else begin
                curr_txn.rdata = vif.HRDATA;
            end
            curr_txn.resp = vif.HRESP;
            
            item_collected_port.write(curr_txn);
        end
    endtask
endclass

`endif
