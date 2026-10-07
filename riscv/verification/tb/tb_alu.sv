module tb_alu;
  import riscv_pkg::*;
  
  exec_op_t op;
  logic [31:0] a, b, res;
  bit pass = 1'b1;

  alu dut(.*);

  initial begin
    // ADD
    op = ALU_ADD; a = 32'd10; b = 32'd20; #1;
    assert(res == 32'd30) else begin pass = 1'b0; $error("ALU_ADD failed"); end

    // SUB
    op = ALU_SUB; a = 32'd20; b = 32'd10; #1;
    assert(res == 32'd10) else begin pass = 1'b0; $error("ALU_SUB failed"); end

    // XOR
    op = ALU_XOR; a = 32'hFFFF0000; b = 32'h00FFFF00; #1;
    assert(res == 32'hFF00FF00) else begin pass = 1'b0; $error("ALU_XOR failed"); end

    // SLT (Signed)
    op = ALU_SLT; a = -32'd10; b = 32'd10; #1;
    assert(res == 32'd1) else begin pass = 1'b0; $error("ALU_SLT failed"); end

    if (pass) $display("PASS");
    else $display("FAIL");
    $finish;
  end
endmodule
