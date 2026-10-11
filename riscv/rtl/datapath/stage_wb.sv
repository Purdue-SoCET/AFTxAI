`timescale 1ns/1ps

module stage_wb (
    // Inputs from EX
    input  logic        ex_valid,
    input  logic [31:0] ex_pc,
    input  logic [31:0] ex_alu_result,
    input  logic [31:0] ex_store_data,
    input  logic [4:0]  ex_rd,
    input  logic        ex_reg_write,
    input  logic [2:0]  ex_mem_size,
    input  logic        ex_mem_read,
    input  logic        ex_mem_write,
    input  logic        ex_wb_src_mem,
    input  logic        ex_wb_src_pc,
    
    // Global State
    input  logic        halt_q,
    
    // Cache interface
    output logic        dcache_valid,
    output logic [31:0] dcache_addr,
    output logic [31:0] dcache_wdata,
    output logic [3:0]  dcache_wstrb,
    input  logic [31:0] dcache_rdata,
    
    // Outputs to EX (Forwarding and RegFile write)
    output logic [31:0] wb_data_out,
    output logic        wb_reg_write_out,
    output logic [4:0]  wb_rd_out
);

    assign dcache_valid = ex_valid && (ex_mem_read || ex_mem_write) && !halt_q;
    assign dcache_addr  = ex_alu_result;
    assign dcache_wdata = ex_store_data;
    
    always_comb begin
        dcache_wstrb = 4'b0000;
        if (ex_valid && ex_mem_write) begin
            case (ex_mem_size[1:0])
                2'b00: dcache_wstrb = 4'b0001; // B
                2'b01: dcache_wstrb = 4'b0011; // H
                2'b10: dcache_wstrb = 4'b1111; // W
                default: dcache_wstrb = 4'b1111;
            endcase
        end
    end

    logic [31:0] load_data;
    always_comb begin
        load_data = dcache_rdata;
        if (ex_valid && ex_mem_read) begin
            case (ex_mem_size)
                3'b000: load_data = {{24{dcache_rdata[7]}}, dcache_rdata[7:0]};
                3'b001: load_data = {{16{dcache_rdata[15]}}, dcache_rdata[15:0]};
                3'b010: load_data = dcache_rdata;
                3'b100: load_data = {24'b0, dcache_rdata[7:0]};
                3'b101: load_data = {16'b0, dcache_rdata[15:0]};
                default: load_data = dcache_rdata;
            endcase
        end
    end

    assign wb_data_out = ex_wb_src_mem ? load_data : 
                         ex_wb_src_pc  ? (ex_pc + 32'd4) : 
                         ex_alu_result;
                         
    assign wb_reg_write_out = ex_reg_write && ex_valid;
    assign wb_rd_out = ex_rd;

endmodule
