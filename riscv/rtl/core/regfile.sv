module regfile #(
  parameter int RV32E = 0
)(
  input  logic        clk,
  input  logic        rst_n,
  input  logic [4:0]  rs1_addr,
  input  logic [4:0]  rs2_addr,
  input  logic [4:0]  rd_addr,
  input  logic [31:0] rd_wdata,
  input  logic        rd_we,
  
  output logic [31:0] rs1_rdata,
  output logic [31:0] rs2_rdata
);

  localparam int NUM_REGS = RV32E ? 16 : 32;

  // x0 is hardwired to 0, so we only instantiate registers 1 through NUM_REGS-1
  logic [31:0] regs [NUM_REGS-1:1];
  logic [31:0] next_regs [NUM_REGS-1:1];

  always_comb begin
    for (int i = 1; i < NUM_REGS; i++) begin
      next_regs[i] = regs[i];
    end
    
    if (rd_we && rd_addr != 5'd0 && rd_addr < NUM_REGS) begin
      next_regs[rd_addr] = rd_wdata;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 1; i < NUM_REGS; i++) begin
        regs[i] <= 32'd0;
      end
    end else begin
      for (int i = 1; i < NUM_REGS; i++) begin
        regs[i] <= next_regs[i];
      end
    end
  end

  // Write-before-read bypass for 1-cycle latency resolution
  assign rs1_rdata = (rs1_addr == 5'd0) ? 32'd0 :
                     (rs1_addr >= NUM_REGS) ? 32'd0 : // RV32E out of bounds protection
                     ((rd_we && (rs1_addr == rd_addr)) ? rd_wdata : regs[rs1_addr]);

  assign rs2_rdata = (rs2_addr == 5'd0) ? 32'd0 :
                     (rs2_addr >= NUM_REGS) ? 32'd0 : // RV32E out of bounds protection
                     ((rd_we && (rs2_addr == rd_addr)) ? rd_wdata : regs[rs2_addr]);

endmodule
