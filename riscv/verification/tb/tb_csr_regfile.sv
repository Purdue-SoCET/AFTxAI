module tb_csr_regfile;
  logic clk=0, rst_n=0;
  logic csr_we, trap_valid, mret_valid;
  logic [11:0] csr_addr;
  logic [31:0] csr_wdata, csr_rdata, trap_pc, trap_cause, trap_tval, trap_target, mret_target;
  logic [2:0] csr_op;
  bit pass = 1'b1;

  csr_regfile dut(.*);
  always #5 clk = ~clk;

  initial begin
    csr_we = 0; csr_addr = 0; csr_wdata = 0; csr_op = 0;
    trap_valid = 0; trap_pc = 0; trap_cause = 0; trap_tval = 0; mret_valid = 0;

    rst_n = 0; #15; rst_n = 1;

    // Write MTVEC
    @(posedge clk);
    csr_we = 1; csr_addr = 12'h305; csr_wdata = 32'h8000_0000; csr_op = 3'b001; // CSRRW
    
    @(posedge clk);
    csr_we = 0; csr_addr = 12'h305; #1;
    assert(csr_rdata == 32'h8000_0000) else begin pass = 1'b0; $error("MTVEC write failed"); end

    // Trap execution
    @(posedge clk);
    trap_valid = 1; trap_pc = 32'h1000; trap_cause = 32'd11; trap_tval = 0;

    @(posedge clk);
    trap_valid = 0; csr_addr = 12'h341; #1; // MEPC
    assert(csr_rdata == 32'h1000) else begin pass = 1'b0; $error("MEPC not updated on trap"); end
    assert(trap_target == 32'h8000_0000) else begin pass = 1'b0; $error("Trap target wrong"); end

    if (pass) $display("PASS");
    else $display("FAIL");
    $finish;
  end
endmodule
