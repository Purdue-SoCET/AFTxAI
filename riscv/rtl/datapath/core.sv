`timescale 1ns/1ps

module core #(
    parameter int RV32E = 0,
    parameter logic [31:0] BOOT_ADDR = 32'h0000_0000
) (
    input  logic HCLK,
    input  logic nRST,

    // Instruction Cache Interface
    cpu_cache_if.cpu icache_if,

    // Data Cache Interface
    cpu_cache_if.cpu dcache_if
);

    // TODO: Implement 3-Stage Pipeline (IF, ID/EX, MEM/WB)
    // TODO: Terminal Halt Logic on illegal instruction or AHB error
    // TODO: 1-cycle IF flush penalty on branch mispredict
    // TODO: Global pipeline stall on cache miss

    // Instantiate Branch Predictor
    branch_predictor #(
        .BHT_ENTRIES(64)
    ) bp_inst (
        .HCLK(HCLK),
        .nRST(nRST),
        .fetch_pc(32'b0),
        .predict_taken(),
        .update_valid(1'b0),
        .update_pc(32'b0),
        .update_taken(1'b0)
    );

    // Instantiate RegFile
    regfile #(
        .NUM_REGS(RV32E ? 16 : 32)
    ) rf_inst (
        .HCLK(HCLK),
        .nRST(nRST),
        .rs1(5'b0),
        .rdata1(),
        .rs2(5'b0),
        .rdata2(),
        .we(1'b0),
        .rd(5'b0),
        .wdata(32'b0)
    );

    // Instantiate ALU
    alu alu_inst (
        .a(32'b0),
        .b(32'b0),
        .alu_op(4'b0),
        .result(),
        .zero()
    );

endmodule
