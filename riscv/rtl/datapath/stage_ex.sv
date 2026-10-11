`timescale 1ns/1ps

module stage_ex #(
    parameter int RV32E = 0
) (
    input  logic HCLK,
    input  logic nRST,
    
    input  logic        global_stall,
    
    // Pipeline in
    input  logic        if_valid_in,
    input  logic [31:0] if_pc_in,
    input  logic [31:0] if_instr_in,
    input  logic        if_pred_taken_in,
    
    // Forwarding
    input  logic [31:0] wb_data_in,
    input  logic        wb_reg_write_in,
    input  logic [4:0]  wb_rd_in,
    
    // Pipeline out
    output logic        ex_valid_out,
    output logic [31:0] ex_pc_out,
    output logic [31:0] ex_alu_result_out,
    output logic [31:0] ex_store_data_out,
    output logic [4:0]  ex_rd_out,
    output logic        ex_reg_write_out,
    output logic [2:0]  ex_mem_size_out,
    output logic        ex_mem_read_out,
    output logic        ex_mem_write_out,
    output logic        ex_wb_src_mem_out,
    output logic        ex_wb_src_pc_out,
    
    // BP Update
    output logic        bp_update_valid,
    output logic [31:0] bp_update_pc,
    output logic        bp_update_taken,
    
    // Hazard & Branch
    output logic        ex_is_branch,
    output logic        ex_branch_taken,
    output logic        ex_pred_taken_out,
    output logic        ex_is_jalr,
    output logic [31:0] mispredict_target_out,
    output logic        illegal_instr
);

    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [4:0] rs1, rs2, rd;
    
    assign opcode = if_instr_in[6:0];
    assign funct3 = if_instr_in[14:12];
    assign funct7 = if_instr_in[31:25];
    assign rs1    = if_instr_in[19:15];
    assign rs2    = if_instr_in[24:20];
    assign rd     = if_instr_in[11:7];

    // -- Submodules --
    logic [31:0] imm;
    logic [2:0]  imm_src;
    
    imm_gen imm_gen_inst (
        .instr(if_instr_in),
        .imm_src(imm_src),
        .imm(imm)
    );

    logic reg_write_ctrl, mem_read_ctrl, mem_write_ctrl, wb_src_mem_ctrl, wb_src_pc_ctrl;
    logic alu_src_a_pc, alu_src_b_imm;
    logic [3:0] alu_op;
    logic is_jal;

    control_unit ctrl_inst (
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .reg_write(reg_write_ctrl),
        .imm_src(imm_src),
        .alu_src_a_pc(alu_src_a_pc),
        .alu_src_b_imm(alu_src_b_imm),
        .alu_op(alu_op),
        .is_branch(ex_is_branch),
        .is_jal(is_jal),
        .is_jalr(ex_is_jalr),
        .mem_read(mem_read_ctrl),
        .mem_write(mem_write_ctrl),
        .mem_size(ex_mem_size_out), // Note: combinational but clocked later
        .wb_src_mem(wb_src_mem_ctrl),
        .wb_src_pc(wb_src_pc_ctrl),
        .illegal_instr(illegal_instr)
    );

    logic [31:0] rdata1, rdata2;
    regfile #(.NUM_REGS(RV32E ? 16 : 32)) rf_inst (
        .HCLK(HCLK), 
        .nRST(nRST),
        .rs1(rs1), 
        .rdata1(rdata1),
        .rs2(rs2), 
        .rdata2(rdata2),
        .we(wb_reg_write_in),
        .rd(wb_rd_in), 
        .wdata(wb_data_in)
    );

    logic fwd_a, fwd_b;
    forwarding_unit fwd_inst (
        .ex_rs1(rs1),
        .ex_rs2(rs2),
        .wb_reg_write(wb_reg_write_in),
        .wb_rd(wb_rd_in),
        .fwd_a(fwd_a),
        .fwd_b(fwd_b)
    );

    logic [31:0] fwd_rs1, fwd_rs2;
    assign fwd_rs1 = fwd_a ? wb_data_in : rdata1;
    assign fwd_rs2 = fwd_b ? wb_data_in : rdata2;

    branch_resolution br_inst (
        .rs1_data(fwd_rs1),
        .rs2_data(fwd_rs2),
        .funct3(funct3),
        .branch_taken(ex_branch_taken)
    );

    logic [31:0] alu_a, alu_b, alu_result;
    assign alu_a = alu_src_a_pc ? if_pc_in : fwd_rs1;
    assign alu_b = alu_src_b_imm ? imm : fwd_rs2;

    alu alu_inst (
        .a(alu_a), 
        .b(alu_b), 
        .alu_op(alu_op),
        .result(alu_result), 
        .zero()
    );

    // -- Branch Prediction Updates --
    assign bp_update_valid = if_valid_in && ex_is_branch && !global_stall;
    assign bp_update_pc    = if_pc_in;
    assign bp_update_taken = ex_branch_taken;
    
    assign ex_pred_taken_out = if_pred_taken_in;

    // Calculate Mispredict Target
    always_comb begin
        mispredict_target_out = 32'b0;
        if (ex_is_jalr) begin
            mispredict_target_out = alu_result & ~32'b1;
        end else if (ex_is_branch) begin
            mispredict_target_out = ex_branch_taken ? (if_pc_in + imm) : (if_pc_in + 32'd4);
        end
    end

    // -- EX/WB Pipeline Registers --
    always_ff @(posedge HCLK or negedge nRST) begin
        if (!nRST) begin
            ex_valid_out <= 1'b0;
            ex_pc_out <= 32'b0;
            ex_alu_result_out <= 32'b0;
            ex_store_data_out <= 32'b0;
            ex_rd_out <= 5'b0;
            ex_reg_write_out <= 1'b0;
            ex_mem_size_out <= 3'b0;
            ex_mem_read_out <= 1'b0;
            ex_mem_write_out <= 1'b0;
            ex_wb_src_mem_out <= 1'b0;
            ex_wb_src_pc_out <= 1'b0;
        end else if (!global_stall) begin
            ex_valid_out <= if_valid_in;
            ex_pc_out <= if_pc_in;
            ex_alu_result_out <= alu_result;
            ex_store_data_out <= fwd_rs2;
            ex_rd_out <= rd;
            ex_reg_write_out <= (if_valid_in && reg_write_ctrl);
            ex_mem_size_out <= funct3;
            ex_mem_read_out <= (if_valid_in && mem_read_ctrl);
            ex_mem_write_out <= (if_valid_in && mem_write_ctrl);
            ex_wb_src_mem_out <= wb_src_mem_ctrl;
            ex_wb_src_pc_out <= wb_src_pc_ctrl;
        end
    end

endmodule
