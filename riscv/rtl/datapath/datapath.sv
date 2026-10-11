`timescale 1ns/1ps

module datapath #(
    parameter int RV32E = 0,
    parameter logic [31:0] BOOT_ADDR = 32'h0000_0000
) (
    input  logic HCLK,
    input  logic nRST,

    // Instruction Cache Interface
    output logic        icache_valid,
    input  logic        icache_ready,
    output logic [31:0] icache_addr,
    input  logic [31:0] icache_rdata,
    input  logic        icache_error,

    // Data Cache Interface
    output logic        dcache_valid,
    input  logic        dcache_ready,
    output logic [31:0] dcache_addr,
    output logic [31:0] dcache_wdata,
    output logic [3:0]  dcache_wstrb,
    input  logic [31:0] dcache_rdata,
    input  logic        dcache_error
);

    // -- Global Stall & Halt Logic --
    logic illegal_instr;
    logic halt_q;
    
    always_ff @(posedge HCLK or negedge nRST) begin
        if (!nRST) halt_q <= 1'b0;
        else if (illegal_instr || icache_error || dcache_error) halt_q <= 1'b1;
    end

    logic global_stall_in;
    assign global_stall_in = halt_q || 
                             (icache_valid && !icache_ready) || 
                             (dcache_valid && !dcache_ready);

    // -- Signals --
    logic global_stall_out, flush_if;
    logic [31:0] mispredict_target;
    
    // BP Interface
    logic bp_predict_taken;
    logic [31:0] fetch_pc;
    logic bp_update_valid;
    logic [31:0] bp_update_pc;
    logic bp_update_taken;
    
    // IF->EX
    logic if_valid;
    logic [31:0] if_pc, if_instr;
    logic if_pred_taken;
    
    // EX->WB
    logic ex_valid;
    logic [31:0] ex_pc, ex_alu_result, ex_store_data;
    logic [4:0] ex_rd;
    logic ex_reg_write;
    logic [2:0] ex_mem_size;
    logic ex_mem_read, ex_mem_write;
    logic ex_wb_src_mem, ex_wb_src_pc;
    
    // Hazard info
    logic ex_is_branch, ex_branch_taken, ex_pred_taken_out, ex_is_jalr;

    // WB->EX Forwarding
    logic [31:0] wb_data;
    logic wb_reg_write;
    logic [4:0] wb_rd;

    // -- Hazard Unit --
    hazard_unit hz_inst (
        .global_stall_in(global_stall_in),
        .ex_is_branch(ex_is_branch),
        .ex_branch_taken(ex_branch_taken),
        .ex_pred_taken(ex_pred_taken_out),
        .ex_is_jalr(ex_is_jalr),
        .global_stall_out(global_stall_out),
        .flush_if(flush_if)
    );

    // -- Branch Predictor --
    branch_predictor #(.BHT_ENTRIES(64)) bp_inst (
        .HCLK(HCLK),
        .nRST(nRST),
        .fetch_pc(fetch_pc),
        .predict_taken(bp_predict_taken),
        .update_valid(bp_update_valid),
        .update_pc(bp_update_pc),
        .update_taken(bp_update_taken)
    );

    // -- Stage: IF --
    assign icache_valid = !halt_q;
    
    stage_if #(.BOOT_ADDR(BOOT_ADDR)) if_inst (
        .HCLK(HCLK),
        .nRST(nRST),
        .global_stall(global_stall_out),
        .flush_if(flush_if),
        .mispredict_target(mispredict_target),
        .icache_rdata(icache_rdata),
        .icache_addr(icache_addr),
        .bp_predict_taken(bp_predict_taken),
        .fetch_pc(fetch_pc),
        .if_valid_out(if_valid),
        .if_pc_out(if_pc),
        .if_instr_out(if_instr),
        .if_pred_taken_out(if_pred_taken)
    );

    // -- Stage: EX --
    stage_ex #(.RV32E(RV32E)) ex_inst (
        .HCLK(HCLK),
        .nRST(nRST),
        .global_stall(global_stall_out),
        .if_valid_in(if_valid),
        .if_pc_in(if_pc),
        .if_instr_in(if_instr),
        .if_pred_taken_in(if_pred_taken),
        .wb_data_in(wb_data),
        .wb_reg_write_in(wb_reg_write),
        .wb_rd_in(wb_rd),
        
        .ex_valid_out(ex_valid),
        .ex_pc_out(ex_pc),
        .ex_alu_result_out(ex_alu_result),
        .ex_store_data_out(ex_store_data),
        .ex_rd_out(ex_rd),
        .ex_reg_write_out(ex_reg_write),
        .ex_mem_size_out(ex_mem_size),
        .ex_mem_read_out(ex_mem_read),
        .ex_mem_write_out(ex_mem_write),
        .ex_wb_src_mem_out(ex_wb_src_mem),
        .ex_wb_src_pc_out(ex_wb_src_pc),
        
        .bp_update_valid(bp_update_valid),
        .bp_update_pc(bp_update_pc),
        .bp_update_taken(bp_update_taken),
        
        .ex_is_branch(ex_is_branch),
        .ex_branch_taken(ex_branch_taken),
        .ex_pred_taken_out(ex_pred_taken_out),
        .ex_is_jalr(ex_is_jalr),
        .mispredict_target_out(mispredict_target),
        .illegal_instr(illegal_instr)
    );

    // -- Stage: WB --
    stage_wb wb_inst (
        .ex_valid(ex_valid),
        .ex_pc(ex_pc),
        .ex_alu_result(ex_alu_result),
        .ex_store_data(ex_store_data),
        .ex_rd(ex_rd),
        .ex_reg_write(ex_reg_write),
        .ex_mem_size(ex_mem_size),
        .ex_mem_read(ex_mem_read),
        .ex_mem_write(ex_mem_write),
        .ex_wb_src_mem(ex_wb_src_mem),
        .ex_wb_src_pc(ex_wb_src_pc),
        .halt_q(halt_q),
        
        .dcache_valid(dcache_valid),
        .dcache_addr(dcache_addr),
        .dcache_wdata(dcache_wdata),
        .dcache_wstrb(dcache_wstrb),
        .dcache_rdata(dcache_rdata),
        
        .wb_data_out(wb_data),
        .wb_reg_write_out(wb_reg_write),
        .wb_rd_out(wb_rd)
    );

endmodule
