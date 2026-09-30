`timescale 1ns/1ps

module memory_stage (
    input  logic clk,
    input  logic rst_n,

    // Interface from Execute
    exec_mem_if.mem em_if,

    // Writeback Interface back to Execute
    mem_wb_if.mem mwb_if,

    // Data Memory Interface
    output logic [31:0] dmem_addr,
    output logic [31:0] dmem_wdata,
    output logic        dmem_read,
    output logic        dmem_write,
    output logic [2:0]  dmem_size,
    input  logic [31:0] dmem_rdata,
    input  logic        dmem_ready
);

    assign dmem_addr  = em_if.alu_result;
    assign dmem_wdata = em_if.store_data;
    assign dmem_read  = em_if.mem_read_en && em_if.valid;
    assign dmem_write = em_if.mem_write_en && em_if.valid;
    assign dmem_size  = em_if.mem_size;

    // Writeback mapping
    always_comb begin
        mwb_if.rd_addr = em_if.rd_addr;
        mwb_if.reg_write_en = em_if.reg_write_en && em_if.valid;
        if (em_if.mem_read_en) begin
            mwb_if.writeback_data = dmem_rdata; // Add load alignment/sign-extension later
        end else begin
            mwb_if.writeback_data = em_if.alu_result;
        end
    end

endmodule
