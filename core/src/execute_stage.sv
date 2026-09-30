`timescale 1ns/1ps

module execute_stage (
    input  logic clk,
    input  logic rst_n,

    // Interface from Fetch
    fetch_exec_if.exec fe_if,
    
    // Interface to Memory
    exec_mem_if.exec em_if,

    // Interface from Memory (Writeback)
    mem_wb_if.exec mwb_if,

    // Hazard and Forwarding unit signals
    input  logic flush,
    output logic [4:0] rs1_addr,
    output logic [4:0] rs2_addr,
    input  logic [31:0] forward_a_val,
    input  logic [31:0] forward_b_val,
    input  logic        use_forward_a,
    input  logic        use_forward_b,

    // Branch resolution outputs to Fetch
    output logic        branch_mispredict,
    output logic [31:0] correct_target_pc
);

    // Register File
    logic [31:0] reg_file [31:1]; // x0 is implicitly 0

    // Decode logic for M, C, B extensions goes here...
    
    // Writeback logic
    always_ff @(posedge clk) begin
        if (mwb_if.reg_write_en && mwb_if.rd_addr != 5'd0) begin
            reg_file[mwb_if.rd_addr] <= mwb_if.writeback_data;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            em_if.valid <= 1'b0;
            branch_mispredict <= 1'b0;
        end else begin
            if (flush) begin
                em_if.valid <= 1'b0;
            end else if (fe_if.inst_valid) begin
                // Pipeline register updates...
                em_if.pc <= fe_if.pc;
                em_if.valid <= 1'b1;
                // ALU and execution logic...
            end else begin
                em_if.valid <= 1'b0;
            end
        end
    end

endmodule
