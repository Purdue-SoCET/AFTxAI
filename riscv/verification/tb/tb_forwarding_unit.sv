module tb_forwarding_unit;
  logic [4:0] id_rs1, id_rs2, mem_rd;
  logic id_uses_rs1, id_uses_rs2, mem_rd_we;
  logic forward_a, forward_b;
  bit pass = 1'b1;

  forwarding_unit dut(.*);

  initial begin
    id_rs1 = 0; id_rs2 = 0; id_uses_rs1 = 0; id_uses_rs2 = 0;
    mem_rd = 0; mem_rd_we = 0;
    #1;

    // Normal forwarding
    id_rs1 = 5'd1; id_uses_rs1 = 1; mem_rd = 5'd1; mem_rd_we = 1; #1;
    assert(forward_a == 1 && forward_b == 0) else begin pass = 1'b0; $error("Fwd A failed"); end

    // x0 should not forward
    id_rs1 = 5'd0; id_uses_rs1 = 1; mem_rd = 5'd0; mem_rd_we = 1; #1;
    assert(forward_a == 0 && forward_b == 0) else begin pass = 1'b0; $error("Fwd x0 failed"); end

    if (pass) $display("PASS");
    else $display("FAIL");
    $finish;
  end
endmodule
