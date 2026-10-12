`ifndef HAZARD_UNIT_IF_SV
`define HAZARD_UNIT_IF_SV
interface hazard_unit_if;
    logic global_stall_in, ex_is_branch, ex_branch_taken, ex_pred_taken, ex_is_jalr, global_stall_out, flush_if; modport mp (input global_stall_in, ex_is_branch, ex_branch_taken, ex_pred_taken, ex_is_jalr, output global_stall_out, flush_if);
endinterface
`endif
