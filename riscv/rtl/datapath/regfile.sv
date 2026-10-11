`timescale 1ns/1ps

module regfile #(
    parameter int NUM_REGS = 32 // 32 for RV32I, 16 for RV32E
) (
    input  logic        HCLK,
    input  logic        nRST,
    
    // Read Port 1
    input  logic [$clog2(NUM_REGS)-1:0] rs1,
    output logic [31:0]                 rdata1,
    
    // Read Port 2
    input  logic [$clog2(NUM_REGS)-1:0] rs2,
    output logic [31:0]                 rdata2,
    
    // Write Port
    input  logic                        we,
    input  logic [$clog2(NUM_REGS)-1:0] rd,
    input  logic [31:0]                 wdata
);

    logic [31:0] registers [NUM_REGS-1:1];

    always_comb begin
        rdata1 = (rs1 == 0) ? 32'b0 : registers[rs1];
        rdata2 = (rs2 == 0) ? 32'b0 : registers[rs2];
    end

    always_ff @(posedge HCLK or negedge nRST) begin
        if (!nRST) begin
            for (int i = 1; i < NUM_REGS; i++) begin
                registers[i] <= 32'b0;
            end
        end else if (we && rd != 0) begin
            registers[rd] <= wdata;
        end
    end

endmodule
