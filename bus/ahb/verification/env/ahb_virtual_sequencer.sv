`ifndef AHB_VIRTUAL_SEQUENCER_SV
`define AHB_VIRTUAL_SEQUENCER_SV

class ahb_virtual_sequencer extends uvm_sequencer;
    `uvm_component_utils(ahb_virtual_sequencer)

    ahb_env_cfg cfg;
    ahb_sequencer mgr_sqrs[];

    function new(string name = "ahb_virtual_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass

`endif
