`ifndef AHB_RESPONDER_SV
`define AHB_RESPONDER_SV

class ahb_responder extends uvm_driver #(ahb_txn);
    `uvm_component_utils(ahb_responder)

    virtual ahb_if vif;
    ahb_agent_cfg cfg;
    
    logic [7:0] mem[logic [31:0]];

    // Queue to hold pending data phases (pipelining)
    ahb_txn pending_data_q[$];

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
        vif.HREADYOUT <= 1'b1;
        vif.HRESP <= 1'b0;
        vif.HRDATA <= 0;
        
        wait(vif.HRESETn);
        
        fork
            addr_phase_thread();
            data_phase_thread();
        join
    endtask

    task addr_phase_thread();
        ahb_txn txn;
        forever begin
            @(posedge vif.HCLK);
            #1ps; // Wait for NBA assignments to settle
            // Capture address phase if selected and ready
            if (vif.HSEL && vif.HREADY) begin
                if (vif.HTRANS == ahb_pkg::NONSEQ || vif.HTRANS == ahb_pkg::SEQ) begin
                    txn = ahb_txn::type_id::create("txn");
                    txn.addr = vif.HADDR;
                    txn.write = vif.HWRITE;
                    pending_data_q.push_back(txn);
                end
            end
        end
    endtask

    task data_phase_thread();
        ahb_txn txn;
        int wait_states;
        forever begin
            @(posedge vif.HCLK);
            if (pending_data_q.size() > 0) begin
                txn = pending_data_q.pop_front();
                
                // Determine wait states
                wait_states = 0;
                if (cfg.max_wait_states > 0) begin
                    wait_states = $urandom_range(0, cfg.max_wait_states);
                end
                
                if (wait_states > 0) begin
                    vif.HREADYOUT <= 1'b0;
                    vif.HRESP <= 1'b0; // HRESP must be OKAY during wait states
                    repeat(wait_states) @(posedge vif.HCLK);
                end
                
                // Determine response
                if (cfg.error_prob > 0 && ($urandom_range(1, 100) <= cfg.error_prob)) begin
                    // Two-cycle ERROR response
                    vif.HREADYOUT <= 1'b0;
                    vif.HRESP <= 1'b1; // ERROR
                    @(posedge vif.HCLK);
                    vif.HREADYOUT <= 1'b1;
                    vif.HRESP <= 1'b1;
                end else begin
                    vif.HREADYOUT <= 1'b1;
                    vif.HRESP <= 1'b0; // OKAY
                    if (txn.write) begin
                        mem[txn.addr]   = vif.HWDATA[7:0];
                        mem[txn.addr+1] = vif.HWDATA[15:8];
                        mem[txn.addr+2] = vif.HWDATA[23:16];
                        mem[txn.addr+3] = vif.HWDATA[31:24];
                    end else begin
                        if (!mem.exists(txn.addr)) mem[txn.addr] = 8'h00;
                        if (!mem.exists(txn.addr+1)) mem[txn.addr+1] = 8'h00;
                        if (!mem.exists(txn.addr+2)) mem[txn.addr+2] = 8'h00;
                        if (!mem.exists(txn.addr+3)) mem[txn.addr+3] = 8'h00;
                        vif.HRDATA = {mem[txn.addr+3], mem[txn.addr+2], mem[txn.addr+1], mem[txn.addr]};
                    end
                end
            end else begin
                // IDLE
                vif.HREADYOUT <= 1'b1;
                vif.HRESP <= 1'b0;
            end
        end
    endtask
endclass

`endif