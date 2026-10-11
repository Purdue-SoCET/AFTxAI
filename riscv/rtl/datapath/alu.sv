`timescale 1ns/1ps

module alu (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [3:0]  alu_op,
    output logic [31:0] result,
    output logic        zero
);
    // TODO: Implement RV32I ALU operations
    always_comb begin
        result = 32'b0;
        zero = (result == 32'b0);
    end
endmodule
