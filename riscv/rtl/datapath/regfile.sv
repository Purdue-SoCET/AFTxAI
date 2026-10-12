`timescale 1ns/1ps
module regfile #(parameter int NUM_REGS = 32) (
    input logic HCLK, input logic nRST,
    regfile_if.mp port
);
    logic [31:0] registers [NUM_REGS-1:1];
    logic [31:0] next_registers [NUM_REGS-1:1];

    always_comb begin
        port.rdata1 = (port.rs1 == 0) ? 32'b0 : registers[port.rs1];
        port.rdata2 = (port.rs2 == 0) ? 32'b0 : registers[port.rs2];
        next_registers = registers;
        if (port.we && port.rd != 0) begin
            next_registers[port.rd] = port.wdata;
        end
    end

    always_ff @(posedge HCLK or negedge nRST) begin
        if (!nRST) begin
            for (int i = 1; i < NUM_REGS; i++) registers[i] <= 32'b0;
        end else begin
            registers <= next_registers;
        end
    end
endmodule
