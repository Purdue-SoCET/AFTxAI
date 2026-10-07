class riscv_monitor extends uvm_monitor;
  `uvm_component_utils(riscv_monitor)

  virtual riscv_if vif;
  uvm_analysis_port #(riscv_instr_item) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual riscv_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("MON", "Could not get vif config")
    end
  endfunction

  task run_phase(uvm_phase phase);
    riscv_instr_item item;
    forever begin
      @(posedge vif.clk);
      if (vif.rst_n && vif.req && vif.ack) begin
        item = riscv_instr_item::type_id::create("item");
        item.instr_bits = vif.instr;
        // In a real monitor, you would extract fields from instr_bits back into the item variables
        `uvm_info("MON", $sformatf("Observed transaction on bus: 32'h%08x", item.instr_bits), UVM_LOW)
        ap.write(item);
      end
    end
  endtask
endclass