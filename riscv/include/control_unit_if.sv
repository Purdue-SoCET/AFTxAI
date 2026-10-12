`ifndef CONTROL_UNIT_IF_SV
`define CONTROL_UNIT_IF_SV
interface control_unit_if;
    logic [6:0] opcode, funct7; logic [2:0] funct3, imm_src, mem_size; logic reg_write, alu_src_a_pc, alu_src_b_imm, is_branch, is_jal, is_jalr, mem_read, mem_write, wb_src_mem, wb_src_pc, illegal_instr; logic [3:0] alu_op; modport mp (input opcode, funct3, funct7, output reg_write, imm_src, alu_src_a_pc, alu_src_b_imm, alu_op, is_branch, is_jal, is_jalr, mem_read, mem_write, mem_size, wb_src_mem, wb_src_pc, illegal_instr);
endinterface
`endif
