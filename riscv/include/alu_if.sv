`ifndef ALU_IF_SV
`define ALU_IF_SV
interface alu_if;
    logic [31:0] a, b, result; logic [3:0] alu_op; logic zero; modport mp (input a, b, alu_op, output result, zero);
endinterface
`endif
