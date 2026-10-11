`timescale 1ns/1ps

module tb_alu;

    logic [31:0] a, b, result;
    logic [3:0]  alu_op;
    logic        zero;

    alu dut (
        .a(a),
        .b(b),
        .alu_op(alu_op),
        .result(result),
        .zero(zero)
    );

    initial begin
        // TODO: Implement Directed/Random tests for ALU
        $display("Starting ALU Testbench");
        #10;
        $finish;
    end

endmodule
