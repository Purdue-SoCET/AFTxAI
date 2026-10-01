`timescale 1ns/1ps

module memory_stage (
    input  logic clk,
    input  logic rst_n,

    // Interfaces
    exec_mem_if.mem em_if,
    mem_wb_if.mem   mwb_if,

    // Data Cache Interface
    output logic [31:0] dcache_addr,
    output logic [31:0] dcache_wdata,
    output logic        dcache_read,
    output logic        dcache_write,
    output logic [2:0]  dcache_size,
    input  logic [31:0] dcache_rdata,
    input  logic        dcache_ready
);

    assign dcache_addr  = em_if.alu_result;
    assign dcache_wdata = em_if.store_data;
    assign dcache_read  = em_if.mem_read_en && em_if.valid;
    assign dcache_write = em_if.mem_write_en && em_if.valid;
    assign dcache_size  = em_if.mem_size;

    // Writeback logic
    always_comb begin
        mwb_if.rd_addr = em_if.rd_addr;
        mwb_if.reg_write_en = em_if.reg_write_en && em_if.valid;
        if (em_if.mem_read_en) begin
            mwb_if.writeback_data = dcache_rdata; // Add load formatting later
        end else begin
            mwb_if.writeback_data = em_if.alu_result;
        end
    end

endmodule