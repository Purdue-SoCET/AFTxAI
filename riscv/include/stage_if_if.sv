`ifndef STAGE_IF_IF_SV
`define STAGE_IF_IF_SV
interface stage_if_if;
    logic global_stall, flush_if; logic [31:0] mispredict_target, icache_rdata, icache_addr; logic bp_predict_taken; logic [31:0] fetch_pc; logic if_valid_out, if_pred_taken_out; logic [31:0] if_pc_out, if_instr_out; modport mp (input global_stall, flush_if, mispredict_target, icache_rdata, bp_predict_taken, output icache_addr, fetch_pc, if_valid_out, if_pred_taken_out, if_pc_out, if_instr_out);
endinterface
`endif
