`timescale 1ns/1ps

module imm_gen (
    input  logic [31:0] instr,
    input  logic [2:0]  imm_src,
    output logic [31:0] imm
);
    always_comb begin
        case (imm_src)
            3'd0: imm = {{20{instr[31]}}, instr[31:20]}; // I-type
            3'd1: imm = {{20{instr[31]}}, instr[31:25], instr[11:7]}; // S-type
            3'd2: imm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0}; // B-type
            3'd3: imm = {instr[31:12], 12'b0}; // U-type
            3'd4: imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0}; // J-type
            default: imm = 32'b0;
        endcase
    end
endmodule
