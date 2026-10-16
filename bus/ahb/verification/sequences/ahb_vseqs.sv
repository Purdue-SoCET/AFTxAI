`ifndef AHB_VSEQS_SV
`define AHB_VSEQS_SV

// Base virtual sequence
class ahb_base_vseq extends uvm_sequence;
    `uvm_object_utils(ahb_base_vseq)
    `uvm_declare_p_sequencer(ahb_virtual_sequencer)

    function new(string name = "ahb_base_vseq");
        super.new(name);
    endfunction

    // Helper method to get the number of managers
    virtual function int get_num_managers();
        if (p_sequencer != null && p_sequencer.cfg != null) begin
            return p_sequencer.cfg.num_managers;
        end
        return 0;
    endfunction
endclass

// Basic random regression virtual sequence
class ahb_random_vseq extends ahb_base_vseq;
    `uvm_object_utils(ahb_random_vseq)

    rand int num_txns;
    
    constraint num_txns_c {
        num_txns inside {[100:300]};
    }

    function new(string name = "ahb_random_vseq");
        super.new(name);
    endfunction

    virtual task body();
        int n_managers = get_num_managers();
        if (n_managers == 0) begin
            `uvm_fatal("VSEQ", "Number of managers is 0 or virtual sequencer not configured properly")
        end

        `uvm_info("VSEQ", $sformatf("Starting random regression with %0d transactions across %0d managers", num_txns, n_managers), UVM_LOW)

        // Generate random traffic concurrently on all managers
        for (int i = 0; i < n_managers; i++) begin
            automatic int mgr_idx = i;
            fork
                begin
                    ahb_txn txn;
                    for (int j = 0; j < num_txns; j++) begin
                        txn = ahb_txn::type_id::create("txn");
                        start_item(txn, -1, p_sequencer.mgr_sqrs[mgr_idx]);
                        if (!txn.randomize() with {
                            trans inside {ahb_pkg::NONSEQ, ahb_pkg::SEQ};
                            // Burst, size, and addr unconstrained to hit all coverage bins
                            // Give higher probability to mapped addresses, but allow unmapped
                            addr dist {
                                [32'h0000_0000 : 32'h3FFF_FFFF] := 80,
                                [32'h4000_0000 : 32'hFFFF_FFFF] := 20
                            };
                            // Sizes: BYTE, HALFWORD, WORD. (Data bus is 32-bit, so avoid wider)
                            size inside {ahb_pkg::BYTE, ahb_pkg::HALFWORD, ahb_pkg::WORD};
                        }) begin
                            `uvm_error("VSEQ", "Failed to randomize txn")
                        end
                        finish_item(txn);
                    end
                end
            join_none
        end
        wait fork;

        `uvm_info("VSEQ", "Random regression scenario complete", UVM_LOW)
    endtask
endclass

// Matrix concurrent virtual sequence
class ahb_matrix_vseq extends ahb_base_vseq;
    `uvm_object_utils(ahb_matrix_vseq)

    rand int num_txns;
    
    constraint num_txns_c {
        num_txns inside {[200:500]};
    }

    function new(string name = "ahb_matrix_vseq");
        super.new(name);
    endfunction

    virtual task body();
        int n_managers = get_num_managers();
        if (n_managers == 0) begin
            `uvm_fatal("VSEQ", "Number of managers is 0 or virtual sequencer not configured properly")
        end

        `uvm_info("VSEQ", $sformatf("Starting matrix concurrent traffic with %0d transactions across %0d managers", num_txns, n_managers), UVM_LOW)

        // Generate random traffic concurrently on all managers
        for (int i = 0; i < n_managers; i++) begin
            automatic int mgr_idx = i;
            fork
                begin
                    ahb_txn txn;
                    for (int j = 0; j < num_txns; j++) begin
                        txn = ahb_txn::type_id::create("txn");
                        start_item(txn, -1, p_sequencer.mgr_sqrs[mgr_idx]);
                        if (!txn.randomize() with {
                            trans inside {ahb_pkg::NONSEQ, ahb_pkg::SEQ}; 
                            addr dist {
                                [32'h0000_0000 : 32'h3FFF_FFFF] := 80,
                                [32'h4000_0000 : 32'hFFFF_FFFF] := 20
                            };
                            size inside {ahb_pkg::BYTE, ahb_pkg::HALFWORD, ahb_pkg::WORD};
                        }) begin
                            `uvm_error("VSEQ", "Failed to randomize txn")
                        end
                        finish_item(txn);
                    end
                end
            join_none
        end
        wait fork;

        `uvm_info("VSEQ", "Matrix concurrent scenario complete", UVM_LOW)
    endtask
endclass

`endif
