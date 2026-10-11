`timescale 1ns/1ps

module hazard_unit (
    input  logic global_stall_in,
    input  logic ex_is_branch,
    input  logic ex_branch_taken,
    input  logic ex_pred_taken,
    input  logic ex_is_jalr,
    
    output logic global_stall_out,
    output logic flush_if
);
    assign global_stall_out = global_stall_in;
    // Flush IF if mispredicted branch or if it's a JALR (which always flushes)
    assign flush_if = (ex_is_branch && (ex_branch_taken != ex_pred_taken)) || ex_is_jalr;
endmodule
