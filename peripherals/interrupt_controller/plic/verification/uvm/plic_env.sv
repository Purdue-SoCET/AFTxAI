`ifndef PLIC_ENV_SV
`define PLIC_ENV_SV

class plic_env extends uvm_env;
    `uvm_component_utils(plic_env)

    bus_agent       b_agent;
    irq_agent       i_agent;
    plic_scoreboard scb;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        b_agent = bus_agent::type_id::create("b_agent", this);
        i_agent = irq_agent::type_id::create("i_agent", this);
        scb = plic_scoreboard::type_id::create("scb", this);
        
        // Pass virtual interfaces from config db to agents if needed,
        // although usually agents do this themselves.
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        b_agent.monitor.ap.connect(scb.bus_export);
        i_agent.monitor.ap.connect(scb.irq_export);
    endfunction
endclass

`endif