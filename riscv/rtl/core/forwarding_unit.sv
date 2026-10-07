module forwarding_unit (
  input  logic [4:0] id_rs1,
  input  logic [4:0] id_rs2,
  input  logic       id_uses_rs1,
  input  logic       id_uses_rs2,
  input  logic [4:0] mem_rd,
  input  logic       mem_rd_we,
  output logic       forward_a,
  output logic       forward_b
);

  // Forward only if MEM/WB stage is writing to a non-zero register 
  // that matches the source register used by ID/EX.
  always_comb begin
    forward_a = 1'b0;
    forward_b = 1'b0;
    
    if (mem_rd_we && (mem_rd != 5'd0)) begin
      if (id_uses_rs1 && (mem_rd == id_rs1)) forward_a = 1'b1;
      if (id_uses_rs2 && (mem_rd == id_rs2)) forward_b = 1'b1;
    end
  end

endmodule
