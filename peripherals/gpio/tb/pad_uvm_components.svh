    class pad_seq_item extends uvm_sequence_item;
        rand bit [31:0] pins;
        rand int        delay;
        
        constraint c_delay { delay inside {[0:10]}; }

        `uvm_object_utils_begin(pad_seq_item)
            `uvm_field_int(pins, UVM_ALL_ON)
            `uvm_field_int(delay, UVM_ALL_ON)
        `uvm_object_utils_end

        function new(string name = "pad_seq_item");
            super.new(name);
        endfunction
    endclass

    class pad_driver extends uvm_driver #(pad_seq_item);
        `uvm_component_utils(pad_driver)
        virtual gpio_pad_if#(32) vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            forever begin
                seq_item_port.get_next_item(req);
                if (req.delay > 0)
                    repeat(req.delay) @(posedge vif.pclk);
                else
                    @(posedge vif.pclk); // at least one cycle
                vif.in <= req.pins;
                seq_item_port.item_done();
            end
        endtask
    endclass

    class pad_agent extends uvm_agent;
        `uvm_component_utils(pad_agent)
        pad_driver driver;
        uvm_sequencer #(pad_seq_item) sequencer;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            driver = pad_driver::type_id::create("driver", this);
            sequencer = uvm_sequencer#(pad_seq_item)::type_id::create("sequencer", this);
            if (!uvm_config_db#(virtual gpio_pad_if#(32))::get(this, "", "pad_vif", driver.vif))
                `uvm_fatal("NO_VIF", "Virtual interface not found in config_db for pad_driver")
        endfunction

        function void connect_phase(uvm_phase phase);
            driver.seq_item_port.connect(sequencer.seq_item_export);
        endfunction
    endclass
