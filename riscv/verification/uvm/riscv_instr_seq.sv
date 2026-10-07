class riscv_instr_seq extends uvm_sequence #(riscv_instr_item);
  `uvm_object_utils(riscv_instr_seq)

  function new(string name = "riscv_instr_seq");
    super.new(name);
  endfunction

  task body();
    repeat(10) begin
      req = riscv_instr_item::type_id::create("req");
      start_item(req);
      if (!req.randomize()) begin
        `uvm_error("SEQ", "Randomization failed")
      end
      finish_item(req);
    end
  endtask
endclass