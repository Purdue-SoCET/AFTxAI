package timer_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    class timer_item extends uvm_sequence_item;
        rand bit [12:0] paddr;
        rand bit [31:0] pwdata;
        rand bit        pwrite;
        rand bit [3:0]  pstrb;
        rand bit [2:0]  pprot;
        
        bit [31:0] prdata;
        bit        pslverr;
        
        // Indicates if this item is APB
        rand bit is_apb; 

        `uvm_object_utils(timer_item)

        constraint c_valid_paddr {
            paddr inside {13'h00, 13'h04, 13'h08, 13'h0C, 13'h10, 13'h14, 13'h18, 13'h1C};
        }

        function new(string name = "timer_item");
            super.new(name);
        endfunction
    endclass

    class timer_driver extends uvm_driver #(timer_item);
        `uvm_component_utils(timer_driver)

        virtual apb4_if #(.ADDR_WIDTH(13), .DATA_WIDTH(32)) vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual apb4_if #(.ADDR_WIDTH(13), .DATA_WIDTH(32)))::get(this, "", "vif", vif))
                `uvm_fatal("DRV", "Could not get vif")
        endfunction

        task run_phase(uvm_phase phase);
            vif.psel <= 0;
            vif.penable <= 0;
            forever begin
                seq_item_port.get_next_item(req);
                if (req.is_apb) begin
                    @(posedge vif.pclk);
                    vif.paddr <= req.paddr;
                    vif.psel <= 1;
                    vif.penable <= 0;
                    vif.pwrite <= req.pwrite;
                    vif.pwdata <= req.pwdata;
                    vif.pstrb <= req.pstrb;
                    vif.pprot <= req.pprot;
                    @(posedge vif.pclk);
                    vif.penable <= 1;
                    @(posedge vif.pclk);
                    req.prdata = vif.prdata;
                    req.pslverr = vif.pslverr;
                    vif.psel <= 0;
                    vif.penable <= 0;
                end
                seq_item_port.item_done();
            end
        endtask
    endclass

    class timer_monitor extends uvm_monitor;
        `uvm_component_utils(timer_monitor)

        virtual apb4_if #(.ADDR_WIDTH(13), .DATA_WIDTH(32)) vif;
        uvm_analysis_port #(timer_item) ap;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            ap = new("ap", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual apb4_if #(.ADDR_WIDTH(13), .DATA_WIDTH(32)))::get(this, "", "vif", vif))
                `uvm_fatal("MON", "Could not get vif")
        endfunction

        task run_phase(uvm_phase phase);
            timer_item item;
            forever begin
                @(posedge vif.pclk);
                if (vif.psel && vif.penable && vif.pready) begin
                    item = timer_item::type_id::create("item");
                    item.is_apb = 1;
                    item.paddr = vif.paddr;
                    item.pwrite = vif.pwrite;
                    item.pwdata = vif.pwdata;
                    item.pstrb = vif.pstrb;
                    item.pprot = vif.pprot;
                    item.prdata = vif.prdata;
                    item.pslverr = vif.pslverr;
                    ap.write(item);
                end
            end
        endtask
    endclass

    class timer_agent extends uvm_agent;
        `uvm_component_utils(timer_agent)

        uvm_sequencer #(timer_item) sqr;
        timer_driver drv;
        timer_monitor mon;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sqr = uvm_sequencer#(timer_item)::type_id::create("sqr", this);
            drv = timer_driver::type_id::create("drv", this);
            mon = timer_monitor::type_id::create("mon", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            drv.seq_item_port.connect(sqr.seq_item_export);
        endfunction
    endclass

    class timer_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(timer_scoreboard)

        uvm_analysis_imp #(timer_item, timer_scoreboard) ap_imp;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            ap_imp = new("ap_imp", this);
        endfunction

        function void write(timer_item t);
            if (t.is_apb) begin
                // Simple checking placeholder
                if (t.pwrite && !t.pslverr) begin
                    `uvm_info("SCB", $sformatf("Valid write to %0h", t.paddr), UVM_LOW)
                end
            end
        endfunction
    endclass

    class timer_env extends uvm_env;
        `uvm_component_utils(timer_env)

        timer_agent agt;
        timer_scoreboard scb;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            agt = timer_agent::type_id::create("agt", this);
            scb = timer_scoreboard::type_id::create("scb", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            agt.mon.ap.connect(scb.ap_imp);
        endfunction
    endclass

    class timer_rand_seq extends uvm_sequence #(timer_item);
        `uvm_object_utils(timer_rand_seq)

        function new(string name = "timer_rand_seq");
            super.new(name);
        endfunction

        task body();
            timer_item req;
            repeat(50) begin
                req = timer_item::type_id::create("req");
                start_item(req);
                req.is_apb = 1;
                if (!req.randomize()) `uvm_error("SEQ", "Randomize failed")
                finish_item(req);
            end
        endtask
    endclass

    class timer_base_test extends uvm_test;
        `uvm_component_utils(timer_base_test)

        timer_env env;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = timer_env::type_id::create("env", this);
        endfunction

        task run_phase(uvm_phase phase);
            timer_rand_seq seq;
            phase.raise_objection(this);
            seq = timer_rand_seq::type_id::create("seq");
            seq.start(env.agt.sqr);
            #1000;
            phase.drop_objection(this);
        endtask
    endclass

endpackage
