`ifndef BRANCH_PREDICTOR_IF_SV
`define BRANCH_PREDICTOR_IF_SV
interface branch_predictor_if;
    logic [31:0] fetch_pc, update_pc; logic predict_taken, update_valid, update_taken; modport mp (input fetch_pc, update_valid, update_pc, update_taken, output predict_taken);
endinterface
`endif
