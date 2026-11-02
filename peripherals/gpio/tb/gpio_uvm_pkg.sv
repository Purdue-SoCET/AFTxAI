package gpio_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    class apb_seq_item extends uvm_sequence_item;
        rand bit [7:0]  paddr;
        rand bit        pwrite;
        rand bit [31:0] pwdata;
        rand bit [3:0]  pstrb;
        bit [31:0]      prdata;
        bit             pslverr;

        `uvm_object_utils_begin(apb_seq_item)
            `uvm_field_int(paddr, UVM_ALL_ON)
            `uvm_field_int(pwrite, UVM_ALL_ON)
            `uvm_field_int(pwdata, UVM_ALL_ON)
            `uvm_field_int(pstrb, UVM_ALL_ON)
            `uvm_field_int(prdata, UVM_ALL_ON)
            `uvm_field_int(pslverr, UVM_ALL_ON)
        `uvm_object_utils_end

        function new(string name = "apb_seq_item");
            super.new(name);
        endfunction
    endclass

    class apb_driver extends uvm_driver #(apb_seq_item);
        `uvm_component_utils(apb_driver)
        virtual apb4_if vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            vif.psel <= 0;
            vif.penable <= 0;
            forever begin
                seq_item_port.get_next_item(req);
                @(posedge vif.pclk);
                vif.psel <= 1;
                vif.paddr <= req.paddr;
                vif.pwrite <= req.pwrite;
                if (req.pwrite) begin
                    vif.pwdata <= req.pwdata;
                    vif.pstrb <= req.pstrb;
                end else begin
                    vif.pstrb <= 4'h0;
                end
                vif.penable <= 0;
                @(posedge vif.pclk);
                vif.penable <= 1;
                @(posedge vif.pclk);
                req.prdata = vif.prdata;
                req.pslverr = vif.pslverr;
                vif.psel <= 0;
                vif.penable <= 0;
                seq_item_port.item_done();
            end
        endtask
    endclass

    class apb_monitor extends uvm_monitor;
        `uvm_component_utils(apb_monitor)
        virtual apb4_if vif;
        uvm_analysis_port #(apb_seq_item) ap;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            ap = new("ap", this);
        endfunction

        task run_phase(uvm_phase phase);
            apb_seq_item item;
            forever begin
                @(posedge vif.pclk);
                if (vif.psel && vif.penable) begin
                    item = apb_seq_item::type_id::create("item");
                    item.paddr = vif.paddr;
                    item.pwrite = vif.pwrite;
                    item.pwdata = vif.pwdata;
                    item.pstrb = vif.pstrb;
                    item.prdata = vif.prdata;
                    item.pslverr = vif.pslverr;
                    ap.write(item);
                end
            end
        endtask
    endclass

    class apb_agent extends uvm_agent;
        `uvm_component_utils(apb_agent)
        apb_driver driver;
        apb_monitor monitor;
        uvm_sequencer #(apb_seq_item) sequencer;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            driver = apb_driver::type_id::create("driver", this);
            monitor = apb_monitor::type_id::create("monitor", this);
            sequencer = uvm_sequencer#(apb_seq_item)::type_id::create("sequencer", this);
            if (!uvm_config_db#(virtual apb4_if)::get(this, "", "vif", driver.vif))
                `uvm_fatal("NO_VIF", "Virtual interface not found in config_db for driver")
            if (!uvm_config_db#(virtual apb4_if)::get(this, "", "vif", monitor.vif))
                `uvm_fatal("NO_VIF", "Virtual interface not found in config_db for monitor")
        endfunction

        function void connect_phase(uvm_phase phase);
            driver.seq_item_port.connect(sequencer.seq_item_export);
        endfunction
    endclass

    `include "pad_uvm_components.svh"

    class gpio_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(gpio_scoreboard)
        uvm_analysis_imp #(apb_seq_item, gpio_scoreboard) apb_export;
        virtual gpio_pad_if#(32) pad_vif;
        virtual apb4_if apb_vif;

        bit [31:0] expected_dir = 0;
        bit [31:0] expected_out = 0;
        bit [31:0] expected_pull_up = 0;
        bit [31:0] expected_pull_down = 0;
        bit [31:0] expected_open_drain = 0;
        bit [31:0] expected_rise_en = 0;
        bit [31:0] expected_fall_en = 0;
        bit [31:0] expected_high_en = 0;
        bit [31:0] expected_low_en = 0;
        
        bit [31:0] sync0 = 0, sync1 = 0;
        bit [31:0] sync1_setup = 0;
        bit [31:0] irq_rise_pending = 0;
        bit [31:0] irq_fall_pending = 0;
        bit [31:0] irq_rise_pending_setup = 0;
        bit [31:0] irq_fall_pending_setup = 0;
        int gpio_width = 32;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            apb_export = new("apb_export", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual gpio_pad_if#(32))::get(this, "", "pad_vif", pad_vif))
                `uvm_fatal("NO_VIF", "Virtual interface not found for scoreboard pad_vif")
            if (!uvm_config_db#(virtual apb4_if)::get(this, "", "vif", apb_vif))
                `uvm_fatal("NO_VIF", "Virtual interface not found for scoreboard apb_vif")
            uvm_config_db#(int)::get(this, "", "gpio_width", gpio_width);
        endfunction

        bit [31:0] w1c_rise = 0;
        bit [31:0] w1c_fall = 0;

        task run_phase(uvm_phase phase);
            bit [31:0] active_mask = (gpio_width == 32) ? 32'hFFFF_FFFF : ((1 << gpio_width) - 1);
            forever begin
                @(posedge pad_vif.pclk);
                if (!pad_vif.presetn) begin
                    sync0 <= pad_vif.in & active_mask;
                    sync1 <= pad_vif.in & active_mask;
                    sync1_setup <= pad_vif.in & active_mask;
                    irq_rise_pending <= 0;
                    irq_fall_pending <= 0;
                    irq_rise_pending_setup <= 0;
                    irq_fall_pending_setup <= 0;
                end else begin
                    bit [31:0] old_sync1 = sync1;
                    bit [31:0] old_irq_rise_pending = irq_rise_pending;
                    bit [31:0] old_irq_fall_pending = irq_fall_pending;
                    
                    sync1 = sync0;
                    sync0 = pad_vif.in & active_mask;
                    
                    irq_rise_pending = (irq_rise_pending & ~w1c_rise) | (~old_sync1 & sync1);
                    irq_fall_pending = (irq_fall_pending & ~w1c_fall) | (old_sync1 & ~sync1);
                    
                    if (apb_vif.psel && !apb_vif.penable) begin
                        sync1_setup = old_sync1;
                        irq_rise_pending_setup = old_irq_rise_pending;
                        irq_fall_pending_setup = old_irq_fall_pending;
                    end
                end
                w1c_rise = 0;
                w1c_fall = 0;
            end
        endtask

        virtual function void write(apb_seq_item item);
            bit [31:0] mask;
            bit [31:0] active_mask = (gpio_width == 32) ? 32'hFFFF_FFFF : ((1 << gpio_width) - 1);
            mask = expand_strb(item.pstrb) & active_mask;
            
            if (!item.pslverr && item.pwrite) begin
                if (item.paddr == 8'h04) expected_out = (expected_out & ~mask) | (item.pwdata & mask);
                if (item.paddr == 8'h08) expected_dir = (expected_dir & ~mask) | (item.pwdata & mask);
                if (item.paddr == 8'h0C) expected_out = expected_out | (item.pwdata & mask);
                if (item.paddr == 8'h10) expected_out = expected_out & ~(item.pwdata & mask);
                if (item.paddr == 8'h14) expected_out = expected_out ^ (item.pwdata & mask);
                if (item.paddr == 8'h18) expected_pull_up = (expected_pull_up & ~mask) | (item.pwdata & mask);
                if (item.paddr == 8'h1C) expected_pull_down = (expected_pull_down & ~mask) | (item.pwdata & mask);
                if (item.paddr == 8'h20) expected_open_drain = (expected_open_drain & ~mask) | (item.pwdata & mask);
                if (item.paddr == 8'h24) expected_rise_en = (expected_rise_en & ~mask) | (item.pwdata & mask);
                if (item.paddr == 8'h28) expected_fall_en = (expected_fall_en & ~mask) | (item.pwdata & mask);
                if (item.paddr == 8'h2C) expected_high_en = (expected_high_en & ~mask) | (item.pwdata & mask);
                if (item.paddr == 8'h30) expected_low_en = (expected_low_en & ~mask) | (item.pwdata & mask);
                if (item.paddr == 8'h34) w1c_rise = (item.pwdata & mask); // W1C queued
                if (item.paddr == 8'h38) w1c_fall = (item.pwdata & mask); // W1C queued
            end
            if (!item.pslverr && !item.pwrite) begin
                if (item.paddr == 8'h00 && item.prdata != sync1_setup && item.prdata != sync1 && item.prdata != sync0) 
                    `uvm_warning("SCB", $sformatf("DATA_IN async mismatch: exp %0h, act %0h", sync1_setup, item.prdata))
                if (item.paddr == 8'h04 && item.prdata != expected_out) `uvm_error("SCB", "DATA_OUT mismatch")
                if (item.paddr == 8'h08 && item.prdata != expected_dir) `uvm_error("SCB", "DIR mismatch")
                if (item.paddr == 8'h18 && item.prdata != expected_pull_up) `uvm_error("SCB", "PULL_UP mismatch")
                if (item.paddr == 8'h1C && item.prdata != expected_pull_down) `uvm_error("SCB", "PULL_DOWN mismatch")
                if (item.paddr == 8'h20 && item.prdata != expected_open_drain) `uvm_error("SCB", "OPEN_DRAIN mismatch")
                if (item.paddr == 8'h24 && item.prdata != expected_rise_en) `uvm_error("SCB", "RISE_EN mismatch")
                if (item.paddr == 8'h28 && item.prdata != expected_fall_en) `uvm_error("SCB", "FALL_EN mismatch")
                if (item.paddr == 8'h2C && item.prdata != expected_high_en) `uvm_error("SCB", "HIGH_EN mismatch")
                if (item.paddr == 8'h30 && item.prdata != expected_low_en) `uvm_error("SCB", "LOW_EN mismatch")
                if (item.paddr == 8'h34 && item.prdata != irq_rise_pending_setup && item.prdata != irq_rise_pending) 
                    `uvm_warning("SCB", $sformatf("RISE_PENDING async mismatch: exp %0h, act %0h", irq_rise_pending_setup, item.prdata))
                if (item.paddr == 8'h38 && item.prdata != irq_fall_pending_setup && item.prdata != irq_fall_pending) 
                    `uvm_warning("SCB", $sformatf("FALL_PENDING async mismatch: exp %0h, act %0h", irq_fall_pending_setup, item.prdata))
                if (item.paddr == 8'h3C && item.prdata != (sync1_setup & expected_high_en) && item.prdata != (sync1 & expected_high_en) && item.prdata != (sync0 & expected_high_en)) 
                    `uvm_warning("SCB", $sformatf("IRQ_LEVEL_HIGH async mismatch: exp %0h, act %0h", (sync1_setup & expected_high_en), item.prdata))
                if (item.paddr == 8'h40 && item.prdata != (~sync1_setup & expected_low_en & active_mask) && item.prdata != (~sync1 & expected_low_en & active_mask) && item.prdata != (~sync0 & expected_low_en & active_mask)) 
                    `uvm_warning("SCB", $sformatf("IRQ_LEVEL_LOW async mismatch: exp %0h, act %0h", (~sync1_setup & expected_low_en & active_mask), item.prdata))
            end
        endfunction

        function bit [31:0] expand_strb(bit [3:0] strb);
            return {{8{strb[3]}}, {8{strb[2]}}, {8{strb[1]}}, {8{strb[0]}}};
        endfunction
    endclass

    class gpio_coverage extends uvm_subscriber #(apb_seq_item);
        `uvm_component_utils(gpio_coverage)
        apb_seq_item last_item;

        covergroup apb_cg;
            option.per_instance = 1;
            
            cp_addr: coverpoint last_item.paddr {
                bins mapped_regs[] = {8'h00, 8'h04, 8'h08, 8'h0C, 8'h10, 8'h14, 8'h18, 8'h1C, 8'h20, 8'h24, 8'h28, 8'h2C, 8'h30, 8'h34, 8'h38, 8'h3C, 8'h40, 8'h44};
                bins unmapped = {[8'h48:8'hFC]};
                bins unaligned = {8'h01, 8'h02, 8'h03, 8'h05};
            }
            
            cp_write: coverpoint last_item.pwrite;
            
            cp_strb: coverpoint last_item.pstrb {
                bins all_strbs[] = {[0:15]};
            }
            
            cp_err: coverpoint last_item.pslverr;

            // Basic register access matrix
            cross cp_addr, cp_write, cp_err;
            
            // Strobe variations (only on writes)
            cross cp_addr, cp_strb, cp_write {
                ignore_bins read_strbs = binsof(cp_write) intersect {0};
            }
        endgroup

        function new(string name, uvm_component parent);
            super.new(name, parent);
            apb_cg = new();
        endfunction

        function void write(apb_seq_item t);
            last_item = t;
            apb_cg.sample();
        endfunction
    endclass

    class gpio_env extends uvm_env;
        `uvm_component_utils(gpio_env)
        apb_agent agent;
        pad_agent p_agent;
        gpio_scoreboard scb;
        gpio_coverage cov;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            agent = apb_agent::type_id::create("agent", this);
            p_agent = pad_agent::type_id::create("p_agent", this);
            scb = gpio_scoreboard::type_id::create("scb", this);
            cov = gpio_coverage::type_id::create("cov", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            agent.monitor.ap.connect(scb.apb_export);
            agent.monitor.ap.connect(cov.analysis_export);
        endfunction
    endclass

    class gpio_smoke_seq extends uvm_sequence #(apb_seq_item);
        `uvm_object_utils(gpio_smoke_seq)

        function new(string name = "gpio_smoke_seq");
            super.new(name);
        endfunction

        task body();
            apb_seq_item req = apb_seq_item::type_id::create("req");
            
            start_item(req);
            req.paddr = 8'h08; // DIR
            req.pwrite = 1;
            req.pwdata = 32'hFFFF_FFFF;
            req.pstrb = 4'hF;
            finish_item(req);

            start_item(req);
            req.paddr = 8'h04; // DATA_OUT
            req.pwrite = 1;
            req.pwdata = 32'h1234_5678;
            req.pstrb = 4'hF;
            finish_item(req);

            start_item(req);
            req.paddr = 8'h04;
            req.pwrite = 0;
            finish_item(req);
        endtask
    endclass

    class gpio_random_seq extends uvm_sequence #(apb_seq_item);
        `uvm_object_utils(gpio_random_seq)

        function new(string name = "gpio_random_seq");
            super.new(name);
        endfunction

        task body();
            apb_seq_item req;
            
            // Random accesses to mapped and unmapped spaces
            for (int i = 0; i < 5000; i++) begin
                req = apb_seq_item::type_id::create("req");
                start_item(req);
                assert(req.randomize() with {
                    paddr inside {
                        8'h00, 8'h04, 8'h08, 8'h0C, 8'h10, 8'h14, 8'h18, 8'h1C, 
                        8'h20, 8'h24, 8'h28, 8'h2C, 8'h30, 8'h34, 8'h38, 8'h3C, 8'h40, 8'h44,
                        8'h01, 8'h02, 8'h03, 8'h05, // unaligned
                        [8'h48:8'hFC] // unmapped
                    };
                    if (!pwrite) pstrb == 4'h0;
                });
                finish_item(req);
            end
        endtask
    endclass

    class pad_random_seq extends uvm_sequence #(pad_seq_item);
        `uvm_object_utils(pad_random_seq)

        function new(string name = "pad_random_seq");
            super.new(name);
        endfunction

        task body();
            pad_seq_item req;
            for (int i = 0; i < 500; i++) begin
                req = pad_seq_item::type_id::create("req");
                start_item(req);
                assert(req.randomize() with { delay inside {[1:20]}; });
                finish_item(req);
            end
        endtask
    endclass

    class gpio_base_test extends uvm_test;
        `uvm_component_utils(gpio_base_test)
        gpio_env env;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = gpio_env::type_id::create("env", this);
        endfunction

        task run_phase(uvm_phase phase);
            gpio_smoke_seq seq = gpio_smoke_seq::type_id::create("seq");
            gpio_random_seq rand_seq = gpio_random_seq::type_id::create("rand_seq");
            pad_random_seq pad_seq = pad_random_seq::type_id::create("pad_seq");
            phase.raise_objection(this);
            fork
                begin
                    seq.start(env.agent.sequencer);
                    rand_seq.start(env.agent.sequencer);
                end
                pad_seq.start(env.p_agent.sequencer);
            join
            phase.drop_objection(this);
        endtask
    endclass
endpackage