`timescale 1ns/1ps

module stage_if #(
    parameter logic [31:0] BOOT_ADDR = 32'h0000_0000
) (
    input  logic        HCLK,
    input  logic        nRST,
    
    input  logic        global_stall,
    input  logic        flush_if,
    input  logic [31:0] mispredict_target,
    
    input  logic [31:0] icache_rdata,
    
    output logic [31:0] icache_addr,
    
    // BP Interface
    input  logic        bp_predict_taken,
    output logic [31:0] fetch_pc,
    
    // Pipeline out
    output logic        if_valid_out,
    output logic [31:0] if_pc_out,
    output logic [31:0] if_instr_out,
    output logic        if_pred_taken_out
);

    logic [31:0] pc_q, next_pc;

    assign fetch_pc = pc_q;
    assign icache_addr = pc_q;

    // Decode branch/jump immediates early to allow target prediction
    logic [31:0] if_imm_b;
    assign if_imm_b = {{20{icache_rdata[31]}}, icache_rdata[7], icache_rdata[30:25], icache_rdata[11:8], 1'b0};
    logic [31:0] if_imm_j;
    assign if_imm_j = {{12{icache_rdata[31]}}, icache_rdata[19:12], icache_rdata[20], icache_rdata[30:21], 1'b0};
    
    logic if_is_branch, if_is_jal;
    assign if_is_branch = (icache_rdata[6:0] == 7'b1100011);
    assign if_is_jal    = (icache_rdata[6:0] == 7'b1101111);

    logic [31:0] pc_target_if;
    assign pc_target_if = pc_q + (if_is_jal ? if_imm_j : if_imm_b);

    always_comb begin
        if (flush_if) next_pc = mispredict_target;
        else if (global_stall) next_pc = pc_q;
        else if (if_is_jal || (if_is_branch && bp_predict_taken)) next_pc = pc_target_if;
        else next_pc = pc_q + 32'd4;
    end

    always_ff @(posedge HCLK or negedge nRST) begin
        if (!nRST) begin
            pc_q <= BOOT_ADDR;
            if_valid_out <= 1'b0;
            if_pc_out <= 32'b0;
            if_instr_out <= 32'b0;
            if_pred_taken_out <= 1'b0;
        end else begin
            if (!global_stall) begin
                pc_q <= next_pc;
                
                if (flush_if) begin
                    if_valid_out <= 1'b0;
                    if_pc_out <= 32'b0;
                    if_instr_out <= 32'b0;
                    if_pred_taken_out <= 1'b0;
                end else begin
                    if_valid_out <= 1'b1;
                    if_pc_out <= pc_q;
                    if_instr_out <= icache_rdata;
                    if_pred_taken_out <= (if_is_branch && bp_predict_taken);
                end
            end
        end
    end

endmodule
