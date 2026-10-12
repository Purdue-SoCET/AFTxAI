`timescale 1ns/1ps
module hazard_unit(hazard_unit_if.mp port);
    assign port.global_stall_out = port.global_stall_in;
    assign port.flush_if = (port.ex_is_branch && (port.ex_branch_taken != port.ex_pred_taken)) || port.ex_is_jalr;
endmodule
