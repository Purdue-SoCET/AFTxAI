`ifndef STAGE_EX_IF_SV
`define STAGE_EX_IF_SV
interface stage_ex_if;
    logic global_stall; logic if_valid_in, if_pred_taken_in; logic [31:0] if_pc_in, if_instr_in; logic [31:0] wb_data_in; logic wb_reg_write_in; logic [4:0] wb_rd_in; logic ex_valid_out, ex_reg_write_out, ex_mem_read_out, ex_mem_write_out, ex_wb_src_mem_out, ex_wb_src_pc_out; logic [31:0] ex_pc_out, ex_alu_result_out, ex_store_data_out; logic [4:0] ex_rd_out; logic [2:0] ex_mem_size_out; logic bp_update_valid, bp_update_taken; logic [31:0] bp_update_pc; logic ex_is_branch, ex_branch_taken, ex_pred_taken_out, ex_is_jalr, illegal_instr; logic [31:0] mispredict_target_out; modport mp (input global_stall, if_valid_in, if_pc_in, if_instr_in, if_pred_taken_in, wb_data_in, wb_reg_write_in, wb_rd_in, output ex_valid_out, ex_pc_out, ex_alu_result_out, ex_store_data_out, ex_rd_out, ex_reg_write_out, ex_mem_size_out, ex_mem_read_out, ex_mem_write_out, ex_wb_src_mem_out, ex_wb_src_pc_out, bp_update_valid, bp_update_pc, bp_update_taken, ex_is_branch, ex_branch_taken, ex_pred_taken_out, ex_is_jalr, mispredict_target_out, illegal_instr);
endinterface
`endif
