module tb_hazard_unit;
  logic [4:0] id_rs1, id_rs2, ex_rd;
  logic id_uses_rs1, id_uses_rs2, ex_is_load, ex_is_amo;
  logic mem_is_amo, icache_stall, dcache_stall, branch_mispredict, trap_flush;
  logic stall_if, stall_id, stall_ex, stall_mem;
  logic flush_if, flush_id, flush_ex;
  bit pass = 1'b1;

  hazard_unit dut(.*);

  initial begin
    // default
    id_rs1 = 0; id_rs2 = 0; ex_rd = 0; id_uses_rs1 = 0; id_uses_rs2 = 0;
    ex_is_load = 0; ex_is_amo = 0; mem_is_amo = 0; icache_stall = 0; dcache_stall = 0;
    branch_mispredict = 0; trap_flush = 0;
    #1;

    // Load-Use hazard
    id_rs1 = 5'd1; id_uses_rs1 = 1; ex_is_load = 1; ex_rd = 5'd1; #1;
    assert(stall_id == 1 && stall_if == 1 && flush_id == 1 && stall_ex == 0) 
      else begin pass = 1'b0; $error("Load-Use stall failed"); end

    // Reset
    ex_is_load = 0; id_uses_rs1 = 0; #1;

    // Branch Mispredict
    branch_mispredict = 1; #1;
    assert(flush_if == 1 && flush_id == 1 && flush_ex == 1) 
      else begin pass = 1'b0; $error("Branch Mispredict flush failed"); end

    if (pass) $display("PASS");
    else $display("FAIL");
    $finish;
  end
endmodule
