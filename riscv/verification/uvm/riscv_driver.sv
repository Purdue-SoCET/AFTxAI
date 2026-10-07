class riscv_driver extends uvm_driver #(riscv_instr_item);
  `uvm_component_utils(riscv_driver)

  virtual riscv_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual riscv_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("DRV", "Could not get vif config")
    end
  endfunction

  task run_phase(uvm_phase phase);
    vif.req <= 0;
    vif.instr <= 0;
    forever begin
      @(posedge vif.clk);
      if (!vif.rst_n) continue;

      seq_item_port.get_next_item(req);
      `uvm_info("DRV", $sformatf("Driving instr: %s", req.convert2string()), UVM_LOW)

      vif.req <= 1;
      vif.instr <= req.instr_bits;

      @(posedge vif.clk);
      while(!vif.ack) @(posedge vif.clk); // Wait for DUT to acknowledge

      vif.req <= 0;
      seq_item_port.item_done();
    end
  endtask
endclass