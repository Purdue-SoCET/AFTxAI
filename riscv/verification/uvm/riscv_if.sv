interface riscv_if (input logic clk, input logic rst_n);
  logic        req;
  logic [31:0] instr;
  logic        ack;
endinterface