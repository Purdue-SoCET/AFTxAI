`ifndef PLIC_BUS_AGENT_SV
`define PLIC_BUS_AGENT_SV

class bus_seq_item extends uvm_sequence_item;
    rand bit [31:0] addr;
    rand bit [31:0] data;
    rand bit        is_write;
    bit             error;
    bit [31:0]      rdata;

    `uvm_object_utils_begin(bus_seq_item)
        `uvm_field_int(addr, UVM_ALL_ON)
        `uvm_field_int(data, UVM_ALL_ON)
        `uvm_field_int(is_write, UVM_ALL_ON)
        `uvm_field_int(error, UVM_ALL_ON)
        `uvm_field_int(rdata, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "bus_seq_item");
        super.new(name);
    endfunction
endclass

class bus_driver extends uvm_driver #(bus_seq_item);
    `uvm_component_utils(bus_driver)
    virtual bus_protocol_if vif;
    virtual clk_if clk_vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        vif.wen <= 0;
        vif.ren <= 0;
        vif.addr <= 0;
        vif.wdata <= 0;
        vif.strobe <= 0;
        forever begin
            seq_item_port.get_next_item(req);
            @(posedge clk_vif.clk);
            vif.addr <= req.addr;
            if (req.is_write) begin
                vif.wen <= 1;
                vif.ren <= 0;
                vif.wdata <= req.data;
                vif.strobe <= 4'hF;
            end else begin
                vif.wen <= 0;
                vif.ren <= 1;
            end
            @(posedge clk_vif.clk);
            vif.wen <= 0;
            vif.ren <= 0;
            req.rdata = vif.rdata;
            req.error = vif.error;
            seq_item_port.item_done();
        end
    endtask
endclass

class bus_monitor extends uvm_monitor;
    `uvm_component_utils(bus_monitor)
    virtual bus_protocol_if vif;
    virtual clk_if clk_vif;
    uvm_analysis_port #(bus_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        bus_seq_item item;
        forever begin
            @(posedge clk_vif.clk);
            if (vif.wen || vif.ren) begin
                item = bus_seq_item::type_id::create("item");
                item.is_write = vif.wen;
                item.addr = vif.addr;
                if (vif.wen) item.data = vif.wdata;
                @(posedge clk_vif.clk);
                item.error = vif.error;
                item.rdata = vif.rdata;
                ap.write(item);
            end
        end
    endtask
endclass

class bus_agent extends uvm_agent;
    `uvm_component_utils(bus_agent)
    bus_driver driver;
    bus_monitor monitor;
    uvm_sequencer #(bus_seq_item) sequencer;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor = bus_monitor::type_id::create("monitor", this);
        if (get_is_active() == UVM_ACTIVE) begin
            driver = bus_driver::type_id::create("driver", this);
            sequencer = uvm_sequencer#(bus_seq_item)::type_id::create("sequencer", this);
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        uvm_config_db#(virtual bus_protocol_if)::get(this, "", "vif", monitor.vif);
        uvm_config_db#(virtual clk_if)::get(this, "", "clk_vif", monitor.clk_vif);
        if (get_is_active() == UVM_ACTIVE) begin
            uvm_config_db#(virtual bus_protocol_if)::get(this, "", "vif", driver.vif);
            uvm_config_db#(virtual clk_if)::get(this, "", "clk_vif", driver.clk_vif);
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end
    endfunction
endclass

`endif