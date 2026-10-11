`timescale 1ns/1ps

module forwarding_unit (
    input  logic [4:0] ex_rs1,
    input  logic [4:0] ex_rs2,
    input  logic       wb_reg_write,
    input  logic [4:0] wb_rd,
    output logic       fwd_a,
    output logic       fwd_b
);
    assign fwd_a = (wb_reg_write && (wb_rd != 5'b0) && (wb_rd == ex_rs1));
    assign fwd_b = (wb_reg_write && (wb_rd != 5'b0) && (wb_rd == ex_rs2));
endmodule
