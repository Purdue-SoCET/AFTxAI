`ifndef IMM_GEN_IF_SV
`define IMM_GEN_IF_SV
interface imm_gen_if;
    logic [31:0] instr, imm; logic [2:0] imm_src; modport mp (input instr, imm_src, output imm);
endinterface
`endif
