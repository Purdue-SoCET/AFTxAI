`ifndef AHB_COVERAGE_SV
`define AHB_COVERAGE_SV

class ahb_coverage extends uvm_subscriber #(ahb_txn);
    `uvm_component_utils(ahb_coverage)

    ahb_env_cfg cfg;
    ahb_txn current_txn;
    int current_sub_id;

    covergroup ahb_cg;
        option.per_instance = 1;

        // Basic transaction fields
        cp_mgr: coverpoint current_txn.port_id {
            bins mgrs[] = {[0:3]}; // Configured for 4 managers in tests
        }
        
        cp_sub: coverpoint current_sub_id {
            bins subs[] = {[0:3]}; // Configured for 4 subordinates in tests
            bins unmapped = {-1};
        }
        
        cp_trans: coverpoint current_txn.trans {
            bins nonseq = {ahb_pkg::NONSEQ};
            bins seq = {ahb_pkg::SEQ};
        }
        
        cp_burst: coverpoint current_txn.burst {
            bins single = {ahb_pkg::SINGLE};
            bins incr   = {ahb_pkg::INCR};
            bins wrap4  = {ahb_pkg::WRAP_4};
            bins incr4  = {ahb_pkg::INCR_4};
            bins wrap8  = {ahb_pkg::WRAP_8};
            bins incr8  = {ahb_pkg::INCR_8};
            bins wrap16 = {ahb_pkg::WRAP_16};
            bins incr16 = {ahb_pkg::INCR_16};
        }

        cp_size:  coverpoint current_txn.size {
            bins byte_   = {ahb_pkg::BYTE};
            bins half    = {ahb_pkg::HALFWORD};
            bins word    = {ahb_pkg::WORD};
            // Ignore higher widths for now since our data bus is 32-bit
        }

        cp_write: coverpoint current_txn.write {
            bins read  = {0};
            bins write = {1};
        }
        cp_resp:  coverpoint current_txn.resp {
            bins okay  = {0};
            bins error = {1};
        }

        // Cross manager x subordinate
        cross_mgr_sub: cross cp_mgr, cp_sub;
        
        // Cross trans x burst x size x write
        cross_trans_burst_size_write: cross cp_trans, cp_burst, cp_size, cp_write;

        // Error responses from unmapped regions
        cross_unmapped_error: cross cp_sub, cp_resp {
            ignore_bins mapped_errors = binsof(cp_sub.subs) && binsof(cp_resp.error);
            ignore_bins unmapped_okay = binsof(cp_sub.unmapped) && binsof(cp_resp.okay); // Unmapped cannot be OKAY
        }
    endgroup

    function new(string name = "ahb_coverage", uvm_component parent = null);
        super.new(name, parent);
        ahb_cg = new();
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(ahb_env_cfg)::get(this, "", "cfg", cfg)) begin
            `uvm_fatal("NOCFG", "ahb_env_cfg not found in uvm_config_db")
        end
    endfunction

    virtual function void write(ahb_txn t);
        current_txn = t;
        current_sub_id = cfg.addr_map.decode(t.addr);
        if (current_txn.trans == ahb_pkg::NONSEQ || current_txn.trans == ahb_pkg::SEQ) begin
            ahb_cg.sample();
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("COV_REPORT", $sformatf("ahb_cg Coverage = %0.2f%%", ahb_cg.get_inst_coverage()), UVM_NONE)
    endfunction
endclass

`endif
