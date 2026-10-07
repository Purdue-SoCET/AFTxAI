module tb_branch_predictor;
  logic clk=0, rst_n=0;
  logic [31:0] fetch_pc, pred_target, ex_pc, ex_target;
  logic pred_taken, ex_valid, ex_is_branch, ex_is_jump, ex_actually_taken;
  bit pass = 1'b1;

  branch_predictor dut(.*);
  always #5 clk = ~clk;

  initial begin
    fetch_pc = 0; ex_valid = 0; ex_pc = 0; ex_target = 0; 
    ex_is_branch = 0; ex_is_jump = 0; ex_actually_taken = 0;

    rst_n = 0; #15; rst_n = 1;

    // Train the predictor (Weakly Taken -> Strongly Taken)
    @(posedge clk);
    ex_valid = 1; ex_pc = 32'h1000; ex_is_branch = 1; ex_actually_taken = 1; ex_target = 32'h2000;
    
    @(posedge clk);
    ex_valid = 0; fetch_pc = 32'h1000; #1;
    // BHT initializes to 01 (Weakly Not Taken). One taken branch makes it 10 (Weakly Taken).
    assert(pred_taken == 1 && pred_target == 32'h2000) 
      else begin pass = 1'b0; $error("Predictor training failed"); end

    if (pass) $display("PASS");
    else $display("FAIL");
    $finish;
  end
endmodule
