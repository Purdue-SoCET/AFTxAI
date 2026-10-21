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
        virtual timer_sb_if sb_vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual apb4_if #(.ADDR_WIDTH(13), .DATA_WIDTH(32)))::get(this, "", "vif", vif))
                `uvm_fatal("DRV", "Could not get vif")
            if (!uvm_config_db#(virtual timer_sb_if)::get(this, "", "sb_vif", sb_vif))
                `uvm_fatal("DRV", "Could not get sb_vif")
        endfunction

        task run_phase(uvm_phase phase);
            vif.psel <= 0;
            vif.penable <= 0;
            sb_vif.capture_i <= 0;
            fork
                forever begin
                    // Random capture toggle decoupled from synchronous sampling edges
                    #( $urandom_range(17, 73) * 1ns );
                    if ($urandom_range(0, 100) < 5) sb_vif.capture_i <= ~sb_vif.capture_i;
                end
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
            join
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
        virtual timer_sb_if sb_vif;

        // Simplified Reference Model State
        int shadow_count = 0;
        int shadow_period = -1;
        int shadow_prescale = 0;
        bit shadow_en = 0;
        bit [1:0] shadow_mode = 0;
        bit [3:0] shadow_irq_enable = 0;
        bit [3:0] shadow_irq_pending = 0;
        bit shadow_cap_en = 0;
        bit [1:0] shadow_cap_edge = 0;
        
        bit capture_sync_1 = 0;
        bit capture_sync_2 = 0;
        bit capture_sync_3 = 0;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            ap_imp = new("ap_imp", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual timer_sb_if)::get(this, "", "sb_vif", sb_vif))
                `uvm_fatal("SCB", "Could not get sb_vif")
        endfunction

        task run_phase(uvm_phase phase);
            bit [15:0] phase_cnt = 0;
            forever begin
                @(posedge sb_vif.clk);
                if (!sb_vif.rst_n) begin
                    shadow_count = 0;
                    shadow_period = -1;
                    shadow_prescale = 0;
                    shadow_en = 0;
                    shadow_mode = 0;
                    shadow_irq_enable = 0;
                    shadow_irq_pending = 0;
                    shadow_cap_en = 0;
                    shadow_cap_edge = 0;
                    phase_cnt = 0;
                end else begin
                    if (shadow_en) begin
                        if (phase_cnt == shadow_prescale) begin
                            phase_cnt = 0;
                            shadow_count++;
                            if (shadow_count > shadow_period) begin
                                if (shadow_mode == 2'b00) shadow_count = 0; // periodic
                                else if (shadow_mode == 2'b01) shadow_en = 0; // one-shot
                            end
                        end else begin
                            phase_cnt++;
                        end
                    end else begin
                        phase_cnt = 0;
                    end
                end
            end
        endtask

        function void write(timer_item t);
            if (t.is_apb) begin
                if (t.pwrite && !t.pslverr) begin
                    // Predict state changes based on writes
                    case (t.paddr)
                        13'h0000: begin
                            if (!shadow_en || t.pwdata[0] == 0) begin
                                shadow_en = t.pwdata[0];
                                if (!shadow_en) begin
                                    shadow_mode = t.pwdata[2:1];
                                    shadow_cap_en = t.pwdata[3];
                                    shadow_cap_edge = t.pwdata[5:4];
                                end
                            end
                        end
                        13'h0004: if (!shadow_en) shadow_count = t.pwdata;
                        13'h0008: if (!shadow_en) shadow_period = t.pwdata;
                        13'h000C: if (!shadow_en) shadow_prescale = t.pwdata[15:0];
                        13'h0010: shadow_irq_enable = t.pwdata[3:0];
                        13'h0014: shadow_irq_pending &= ~t.pwdata[3:0];
                    endcase
                end else if (!t.pwrite && !t.pslverr) begin
                    // Compare read data with predicted
                    case (t.paddr)
                        13'h0004: if (t.prdata !== shadow_count) `uvm_error("SCB_FAIL", $sformatf("COUNT mismatch: exp %0h, got %0h", shadow_count, t.prdata))
                        13'h0008: if (t.prdata !== shadow_period) `uvm_error("SCB_FAIL", $sformatf("PERIOD mismatch: exp %0h, got %0h", shadow_period, t.prdata))
                        13'h000C: if (t.prdata !== shadow_prescale) `uvm_error("SCB_FAIL", $sformatf("PRESCALE mismatch: exp %0h, got %0h", shadow_prescale, t.prdata))
                        13'h0010: if (t.prdata !== shadow_irq_enable) `uvm_error("SCB_FAIL", $sformatf("IRQ_EN mismatch: exp %0h, got %0h", shadow_irq_enable, t.prdata))
                    endcase
                end
            end
        endfunction
    endclass

    class timer_cov extends uvm_subscriber #(timer_item);
        `uvm_component_utils(timer_cov)
        timer_item tr;
        
        // Use a handle to the scoreboard to sample current modes
        timer_scoreboard scb;
        
        covergroup cg_timer;
            option.name = "APB_Coverage";
            cp_addr: coverpoint tr.paddr {
                bins ctrl = {13'h00}; bins count = {13'h04}; bins period = {13'h08};
                bins prescale = {13'h0C}; bins irq_en = {13'h10}; bins irq_pend = {13'h14};
                bins capture = {13'h18}; bins info = {13'h1C}; bins invalid = {[13'h20:13'h1FFF]};
            }
            cp_write: coverpoint tr.pwrite;
            cp_err: coverpoint tr.pslverr;
            cp_strb: coverpoint tr.pstrb { bins full={4'hF}; bins zero={4'h0}; bins partial={[4'h1:4'hE]}; }
            cr_addr_write: cross cp_addr, cp_write;
        endgroup
        
        covergroup cg_timer_func;
            option.name = "Timer_Behavioral_Coverage";
            cp_mode: coverpoint scb.shadow_mode {
                bins periodic = {2'b00};
                bins oneshot = {2'b01};
                bins freerun = {2'b10};
            }
            cp_prescale: coverpoint scb.shadow_prescale {
                bins p_zero = {0};
                bins p_small = {[1:15]};
                bins p_large = {[16:65534]};
                bins p_max = {65535};
            }
            cp_irq: coverpoint scb.shadow_irq_pending {
                bins p_match = {1};
                bins p_wrap = {2};
                bins p_capture = {4};
                bins p_overrun = {8};
                bins p_multiple = {[3:15]} iff ($countones(scb.shadow_irq_pending) > 1);
            }
            cp_capture_edge: coverpoint scb.shadow_cap_edge {
                bins e_rising = {2'b00};
                bins e_falling = {2'b01};
                bins e_either = {2'b10};
            }
        endgroup

        function new(string name, uvm_component parent);
            super.new(name, parent);
            cg_timer = new();
            cg_timer_func = new();
        endfunction
        
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
        endfunction

        function void write(timer_item t);
            tr = t;
            if (t.is_apb) begin
                cg_timer.sample();
                if (scb != null) cg_timer_func.sample();
            end
        endfunction
    endclass

    class timer_env extends uvm_env;
        `uvm_component_utils(timer_env)

        timer_agent agt;
        timer_scoreboard scb;
        timer_cov cov;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            agt = timer_agent::type_id::create("agt", this);
            scb = timer_scoreboard::type_id::create("scb", this);
            cov = timer_cov::type_id::create("cov", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            agt.mon.ap.connect(scb.ap_imp);
            agt.mon.ap.connect(cov.analysis_export);
            cov.scb = scb; // Provide scb reference to cov
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
