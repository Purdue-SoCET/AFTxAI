module tb_decoder;
  import riscv_pkg::*;
  
  logic [31:0] instr;
  decoded_instr_t dec;
  bit pass = 1'b1;

  decoder #(.RV32E(0), .EXT_A(1)) dut(
    .instr(instr), .dec(dec)
  );

  initial begin
    // ADD x1, x2, x3
    instr = {7'b0000000, 5'd3, 5'd2, 3'b000, 5'd1, OPC_OP}; #1;
    assert(dec.valid && dec.exec_op == ALU_ADD && dec.uses_rd && dec.uses_rs1 && dec.uses_rs2) 
      else begin pass = 1'b0; $error("ADD decode failed"); end

    // JAL x1, imm
    instr = {1'b0, 10'd4, 1'b0, 8'd0, 5'd1, OPC_JAL}; #1;
    assert(dec.valid && dec.is_jump && dec.uses_rd) 
      else begin pass = 1'b0; $error("JAL decode failed"); end

    // LR.W x1, (x2)
    instr = {5'b00010, 1'b0, 1'b0, 5'd0, 5'd2, 3'b010, 5'd1, OPC_AMO}; #1;
    assert(dec.valid && dec.is_amo && dec.uses_rd && dec.uses_rs1 && dec.exec_op == ALU_ADD) 
      else begin pass = 1'b0; $error("LR.W decode failed"); end

    // Illegal instruction
    instr = 32'hFFFFFFFF; #1;
    assert(dec.is_illegal) else begin pass = 1'b0; $error("Illegal instruction failed"); end

    if (pass) $display("PASS");
    else $display("FAIL");
    $finish;
  end
endmodule
