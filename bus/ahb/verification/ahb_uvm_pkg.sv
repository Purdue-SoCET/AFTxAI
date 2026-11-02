`ifndef AHB_UVM_PKG_SV
`define AHB_UVM_PKG_SV

`timescale 1ns/1ps

package ahb_uvm_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    
    import ahb_pkg::*;

    // Phase 1-2: Transactions and Configs
    `include "agent/ahb_txn.sv"
    `include "env/ahb_addr_map.sv"
    `include "env/ahb_agent_cfg.sv"
    `include "env/ahb_env_cfg.sv"
    
    // Phase 3: Agent Components
    `include "agent/ahb_driver.sv"
    `include "agent/ahb_monitor.sv"
    `include "agent/ahb_responder.sv"
    `include "agent/ahb_sequencer.sv"
    `include "agent/ahb_agent.sv"
    
    // Phase 4: Coverage and Scoreboard
    `include "env/ahb_coverage.sv"
    `include "env/ahb_scoreboard.sv"
    
    // Phase 5: Virtual Sequencer
    `include "env/ahb_virtual_sequencer.sv"
    
    // Phase 8: Virtual Sequences
    `include "sequences/ahb_vseqs.sv"
    
    // Phase 6: Environment
    `include "env/ahb_env.sv"
    
    // Phase 7: Tests
    `include "tests/ahb_base_test.sv"
    `include "tests/ahb_matrix_test.sv"
    `include "tests/ahb_error_test.sv"

endpackage

`endif
