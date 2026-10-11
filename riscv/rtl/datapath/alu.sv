`timescale 1ns/1ps

module alu (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [3:0]  alu_op,
    output logic [31:0] result,
    output logic        zero
);
    always_comb begin
        case (alu_op)
            4'd0: result = a + b;                                // ADD
            4'd1: result = a - b;                                // SUB
            4'd2: result = a << b[4:0];                          // SLL
            4'd3: result = {31'b0, $signed(a) < $signed(b)};     // SLT
            4'd4: result = {31'b0, a < b};                       // SLTU
            4'd5: result = a ^ b;                                // XOR
            4'd6: result = a >> b[4:0];                          // SRL
            4'd7: result = $signed(a) >>> b[4:0];                // SRA
            4'd8: result = a | b;                                // OR
            4'd9: result = a & b;                                // AND
            4'd10: result = b;                                   // PASS_B
            default: result = 32'b0;
        endcase
        zero = (result == 32'b0);
    end
endmodule
