`timescale 1ns/1ps
module stage_if #(parameter logic [31:0] BOOT_ADDR = 32'h0000_0000) (
    input logic HCLK, input logic nRST,
    stage_if_if.mp port
);
    logic [31:0] pc, next_pc;
    assign port.fetch_pc = pc;
    assign port.icache_addr = pc;
    
    logic [31:0] if_imm_b, if_imm_j;
    logic if_is_branch, if_is_jal;
    logic [31:0] pc_target_if;

    assign if_imm_b = {{20{port.icache_rdata[31]}}, port.icache_rdata[7], port.icache_rdata[30:25], port.icache_rdata[11:8], 1'b0};
    assign if_imm_j = {{12{port.icache_rdata[31]}}, port.icache_rdata[19:12], port.icache_rdata[20], port.icache_rdata[30:21], 1'b0};
    assign if_is_branch = (port.icache_rdata[6:0] == 7'b1100011);
    assign if_is_jal    = (port.icache_rdata[6:0] == 7'b1101111);
    assign pc_target_if = pc + (if_is_jal ? if_imm_j : if_imm_b);

    logic next_if_valid_out, next_if_pred_taken_out;
    logic [31:0] next_if_pc_out, next_if_instr_out;

    always_comb begin
        if (port.flush_if) next_pc = port.mispredict_target;
        else if (port.global_stall) next_pc = pc;
        else if (if_is_jal || (if_is_branch && port.bp_predict_taken)) next_pc = pc_target_if;
        else next_pc = pc + 32'd4;

        if (port.global_stall) begin
            next_if_valid_out = port.if_valid_out;
            next_if_pc_out = port.if_pc_out;
            next_if_instr_out = port.if_instr_out;
            next_if_pred_taken_out = port.if_pred_taken_out;
        end else if (port.flush_if) begin
            next_if_valid_out = 1'b0;
            next_if_pc_out = 32'b0;
            next_if_instr_out = 32'b0;
            next_if_pred_taken_out = 1'b0;
        end else begin
            next_if_valid_out = 1'b1;
            next_if_pc_out = pc;
            next_if_instr_out = port.icache_rdata;
            next_if_pred_taken_out = (if_is_branch && port.bp_predict_taken);
        end
    end

    always_ff @(posedge HCLK or negedge nRST) begin
        if (!nRST) begin
            pc <= BOOT_ADDR;
            port.if_valid_out <= 1'b0;
            port.if_pc_out <= 32'b0;
            port.if_instr_out <= 32'b0;
            port.if_pred_taken_out <= 1'b0;
        end else begin
            pc <= next_pc;
            port.if_valid_out <= next_if_valid_out;
            port.if_pc_out <= next_if_pc_out;
            port.if_instr_out <= next_if_instr_out;
            port.if_pred_taken_out <= next_if_pred_taken_out;
        end
    end
endmodule
