module tb_regfile;
  logic clk=0, rst_n=0;
  logic [4:0] rs1_addr, rs2_addr, rd_addr;
  logic [31:0] rd_wdata, rs1_rdata, rs2_rdata;
  logic rd_we;
  bit pass = 1'b1;

  regfile #(.RV32E(0)) dut(.*);

  always #5 clk = ~clk;

  initial begin
    rd_addr = 0; rd_wdata = 0; rd_we = 0; rs1_addr = 0; rs2_addr = 0;
    
    rst_n = 0; #15; rst_n = 1;

    // Test bypass logic (write before read in same cycle)
    @(posedge clk);
    rd_addr = 5'd1; rd_wdata = 32'hDEADBEEF; rd_we = 1'b1;
    rs1_addr = 5'd1; rs2_addr = 5'd0;
    #1;
    assert(rs1_rdata == 32'hDEADBEEF) else begin pass = 1'b0; $error("Bypass failed"); end

    // Test read next cycle
    @(posedge clk);
    rd_we = 1'b0;
    rs1_addr = 5'd1;
    #1;
    assert(rs1_rdata == 32'hDEADBEEF) else begin pass = 1'b0; $error("Read failed"); end

    // Test x0 is hardwired to 0
    @(posedge clk);
    rd_addr = 5'd0; rd_wdata = 32'hFFFFFFFF; rd_we = 1'b1;
    rs1_addr = 5'd0;
    #1;
    assert(rs1_rdata == 32'd0) else begin pass = 1'b0; $error("x0 write failed (should be 0)"); end

    #10;
    if (pass) $display("PASS");
    else $display("FAIL");
    $finish;
  end
endmodule
