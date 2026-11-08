`ifndef HAZARD_UNIT_IF_SV
`define HAZARD_UNIT_IF_SV
interface hazard_unit_if;
    logic global_stall_in;
    logic ex_is_branch, ex_branch_taken, ex_pred_taken, ex_is_jalr;
    logic trap_flush;
    
    logic global_stall_out;
    logic flush_if;
    logic flush_ex;
    
    modport mp (
        input global_stall_in, ex_is_branch, ex_branch_taken, ex_pred_taken, ex_is_jalr, trap_flush, 
        output global_stall_out, flush_if, flush_ex
    );
endinterface
`endif
