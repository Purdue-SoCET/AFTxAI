import riscv_pkg::*;

module alu (
  input  exec_op_t    op,
  input  logic [31:0] a,
  input  logic [31:0] b,
  output logic [31:0] res
);

  always_comb begin
    res = '0;
    case (op)
      ALU_ADD: res = a + b;
      ALU_SUB: res = a - b;
      ALU_SLL: res = a << b[4:0];
      ALU_SLT: res = $signed(a) < $signed(b) ? 32'd1 : 32'd0;
      ALU_SLTU:res = a < b ? 32'd1 : 32'd0;
      ALU_XOR: res = a ^ b;
      ALU_SRL: res = a >> b[4:0];
      ALU_SRA: res = $signed(a) >>> b[4:0];
      ALU_OR:  res = a | b;
      ALU_AND: res = a & b;
      // AMO Operations bypass ALU calculation or are handled in MEM stage; 
      // simple passthrough for addresses or data can be placed here if needed.
      default: res = '0;
    endcase
  end

endmodule
