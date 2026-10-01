`timescale 1ns/1ps

module regfile #(
  parameter bit RV32E = 0 // 0 for RV32I (32 regs), 1 for RV32E (16 regs)
)(
  input  logic        clk,
  input  logic        rst_n,
  
  // Read Port 1
  input  logic [4:0]  rs1_addr_i,
  output logic [31:0] rs1_data_o,
  
  // Read Port 2
  input  logic [4:0]  rs2_addr_i,
  output logic [31:0] rs2_data_o,
  
  // Write Port
  input  logic [4:0]  rd_addr_i,
  input  logic [31:0] rd_data_i,
  input  logic        rd_we_i
);

  localparam NUM_REGS = RV32E ? 16 : 32;
  
  logic [31:0] registers [NUM_REGS-1:1]; // x0 is hardwired to 0

  // Asynchronous read, x0 is always 0
  always_comb begin
    rs1_data_o = (rs1_addr_i == 5'b0) ? 32'b0 : 
                 (rs1_addr_i < NUM_REGS) ? registers[rs1_addr_i] : 32'b0;
                 
    rs2_data_o = (rs2_addr_i == 5'b0) ? 32'b0 : 
                 (rs2_addr_i < NUM_REGS) ? registers[rs2_addr_i] : 32'b0;
  end

  // Synchronous write
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 1; i < NUM_REGS; i++) begin
        registers[i] <= 32'b0;
      end
    end else begin
      if (rd_we_i && (rd_addr_i != 5'b0) && (rd_addr_i < NUM_REGS)) begin
        registers[rd_addr_i] <= rd_data_i;
      end
    end
  end

endmodule