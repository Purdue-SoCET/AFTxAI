`ifndef AHB_SCOREBOARD_SV
`define AHB_SCOREBOARD_SV

class ahb_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(ahb_scoreboard)

    ahb_env_cfg cfg;

    // FIFOs to receive transactions from monitors
    uvm_tlm_analysis_fifo #(ahb_txn) mgr_fifos[];
    uvm_tlm_analysis_fifo #(ahb_txn) sub_fifos[];

    // Queues to hold expected transactions for each subordinate
    // expected_txns[sub_id]
    ahb_txn expected_txns[][$];

    function new(string name = "ahb_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(ahb_env_cfg)::get(this, "", "cfg", cfg)) begin
            `uvm_fatal("NOCFG", "ahb_env_cfg not found in uvm_config_db")
        end

        mgr_fifos = new[cfg.num_managers];
        foreach (mgr_fifos[i]) begin
            mgr_fifos[i] = new($sformatf("mgr_fifos_%0d", i), this);
        end

        sub_fifos = new[cfg.num_subordinates];
        foreach (sub_fifos[i]) begin
            sub_fifos[i] = new($sformatf("sub_fifos_%0d", i), this);
        end

        expected_txns = new[cfg.num_subordinates];
    endfunction

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        
        // Spawn a thread for each manager to process incoming transactions
        foreach (mgr_fifos[i]) begin
            fork
                automatic int mgr_idx = i;
                process_mgr_txns(mgr_idx);
            join_none
        end

        // Spawn a thread for each subordinate to verify transactions
        foreach (sub_fifos[i]) begin
            fork
                automatic int sub_idx = i;
                process_sub_txns(sub_idx);
            join_none
        end
    endtask

    virtual task process_mgr_txns(int mgr_id);
        ahb_txn txn;
        int sub_id;
        forever begin
            mgr_fifos[mgr_id].get(txn);
            if (txn.trans == ahb_pkg::IDLE || txn.trans == ahb_pkg::BUSY) continue;

            sub_id = cfg.addr_map.decode(txn.addr);
            
            if (sub_id != -1) begin
                // It's mapped, expect it at the subordinate
                expected_txns[sub_id].push_back(txn);
                `uvm_info("SCB", $sformatf("Mgr %0d txn routed to Sub %0d: Addr=0x%0h", mgr_id, sub_id, txn.addr), UVM_HIGH)
            end else begin
                // Unmapped address, check that it got an ERROR response
                if (txn.resp != 1'b1) begin // 1 is ERROR
                    `uvm_error("SCB_UNMAPPED", $sformatf("Mgr %0d txn to unmapped addr 0x%0h did not get ERROR response", mgr_id, txn.addr))
                end else begin
                    `uvm_info("SCB", $sformatf("Mgr %0d txn to unmapped addr 0x%0h correctly received ERROR", mgr_id, txn.addr), UVM_HIGH)
                end
            end
        end
    endtask

    virtual task process_sub_txns(int sub_id);
        ahb_txn sub_txn;
        ahb_txn exp_txn;
        int matched_mgr;
        bit found;

        forever begin
            sub_fifos[sub_id].get(sub_txn);
            if (sub_txn.trans == ahb_pkg::IDLE || sub_txn.trans == ahb_pkg::BUSY) continue;

            #1ps; // Wait for manager monitor to push to expected queue due to same-clock event ordering

            found = 0;
            if (expected_txns[sub_id].size() > 0) begin
                exp_txn = expected_txns[sub_id][0];
                if (exp_txn.addr == sub_txn.addr && 
                    exp_txn.write == sub_txn.write && 
                    exp_txn.size == sub_txn.size) begin
                    
                    found = 1;
                    void'(expected_txns[sub_id].pop_front());
                end
            end

            if (found) begin
                // Now perform deep comparison
                if (exp_txn.write) begin
                    if (exp_txn.wdata !== sub_txn.wdata) begin
                        `uvm_error("SCB_WDATA_MISMATCH", $sformatf("Sub %0d wdata mismatch: Exp 0x%0h, Act 0x%0h", sub_id, exp_txn.wdata, sub_txn.wdata))
                    end
                end else begin
                    if (exp_txn.rdata !== sub_txn.rdata) begin
                        `uvm_error("SCB_RDATA_MISMATCH", $sformatf("rdata mismatch at Sub %0d: Exp 0x%0h, Act 0x%0h", sub_id, exp_txn.rdata, sub_txn.rdata))
                    end
                end

                if (exp_txn.resp !== sub_txn.resp) begin
                    `uvm_error("SCB_RESP_MISMATCH", $sformatf("Resp mismatch at Sub %0d: Exp %0b, Act %0b", sub_id, exp_txn.resp, sub_txn.resp))
                end

                `uvm_info("SCB_MATCH", $sformatf("Matched txn at Sub %0d (Addr=0x%0h)", sub_id, sub_txn.addr), UVM_HIGH)
            end else begin
                `uvm_error("SCB_UNEXPECTED", $sformatf("Sub %0d received unexpected txn: Addr=0x%0h", sub_id, sub_txn.addr))
            end
        end
    endtask

    virtual function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        foreach (expected_txns[i]) begin
            if (expected_txns[i].size() > 0) begin
                `uvm_error("SCB_ORPHAN", $sformatf("%0d orphaned txns for Sub %0d", expected_txns[i].size(), i))
            end
        end
    endfunction
endclass

`endif
