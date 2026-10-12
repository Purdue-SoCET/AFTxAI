`timescale 1ns/1ps
module stage_ex #(parameter int RV32E = 0) (
    input logic HCLK, input logic nRST,
    stage_ex_if.mp port
);
    logic [6:0] opcode; logic [2:0] funct3; logic [6:0] funct7;
    logic [4:0] rs1, rs2, rd;
    assign opcode = port.if_instr_in[6:0]; assign funct3 = port.if_instr_in[14:12]; assign funct7 = port.if_instr_in[31:25];
    assign rs1 = port.if_instr_in[19:15]; assign rs2 = port.if_instr_in[24:20]; assign rd = port.if_instr_in[11:7];

    imm_gen_if ig_if();
    assign ig_if.instr = port.if_instr_in;
    imm_gen ig_inst(.port(ig_if.mp));

    control_unit_if cu_if();
    assign cu_if.opcode = opcode; assign cu_if.funct3 = funct3; assign cu_if.funct7 = funct7;
    assign ig_if.imm_src = cu_if.imm_src;
    control_unit cu_inst(.port(cu_if.mp));

    regfile_if rf_if();
    assign rf_if.rs1 = rs1; assign rf_if.rs2 = rs2; assign rf_if.rd = port.wb_rd_in;
    assign rf_if.wdata = port.wb_data_in; assign rf_if.we = port.wb_reg_write_in;
    regfile #(.NUM_REGS(RV32E ? 16 : 32)) rf_inst(.HCLK(HCLK), .nRST(nRST), .port(rf_if.mp));

    forwarding_unit_if fu_if();
    assign fu_if.ex_rs1 = rs1; assign fu_if.ex_rs2 = rs2; assign fu_if.wb_rd = port.wb_rd_in;
    assign fu_if.wb_reg_write = port.wb_reg_write_in;
    forwarding_unit fu_inst(.port(fu_if.mp));

    logic [31:0] fwd_rs1, fwd_rs2;
    assign fwd_rs1 = fu_if.fwd_a ? port.wb_data_in : rf_if.rdata1;
    assign fwd_rs2 = fu_if.fwd_b ? port.wb_data_in : rf_if.rdata2;

    branch_resolution_if br_if();
    assign br_if.rs1_data = fwd_rs1; assign br_if.rs2_data = fwd_rs2; assign br_if.funct3 = funct3;
    branch_resolution br_inst(.port(br_if.mp));

    alu_if alu_if_inst();
    assign alu_if_inst.a = cu_if.alu_src_a_pc ? port.if_pc_in : fwd_rs1;
    assign alu_if_inst.b = cu_if.alu_src_b_imm ? ig_if.imm : fwd_rs2;
    assign alu_if_inst.alu_op = cu_if.alu_op;
    alu alu_inst(.port(alu_if_inst.mp));

    assign port.bp_update_valid = port.if_valid_in && cu_if.is_branch && !port.global_stall;
    assign port.bp_update_pc = port.if_pc_in;
    assign port.bp_update_taken = br_if.branch_taken;
    assign port.ex_pred_taken_out = port.if_pred_taken_in;

    always_comb begin
        port.mispredict_target_out = 32'b0;
        if (cu_if.is_jalr) port.mispredict_target_out = alu_if_inst.result & ~32'b1;
        else if (cu_if.is_branch) port.mispredict_target_out = br_if.branch_taken ? (port.if_pc_in + ig_if.imm) : (port.if_pc_in + 32'd4);
    end
    
    assign port.ex_is_branch = cu_if.is_branch;
    assign port.ex_branch_taken = br_if.branch_taken;
    assign port.ex_is_jalr = cu_if.is_jalr;
    assign port.illegal_instr = cu_if.illegal_instr;

    logic next_ex_valid_out, next_ex_reg_write_out, next_ex_mem_read_out, next_ex_mem_write_out, next_ex_wb_src_mem_out, next_ex_wb_src_pc_out;
    logic [31:0] next_ex_pc_out, next_ex_alu_result_out, next_ex_store_data_out;
    logic [4:0] next_ex_rd_out;
    logic [2:0] next_ex_mem_size_out;

    always_comb begin
        if (port.global_stall) begin
            next_ex_valid_out = port.ex_valid_out; next_ex_pc_out = port.ex_pc_out; next_ex_alu_result_out = port.ex_alu_result_out;
            next_ex_store_data_out = port.ex_store_data_out; next_ex_rd_out = port.ex_rd_out; next_ex_reg_write_out = port.ex_reg_write_out;
            next_ex_mem_size_out = port.ex_mem_size_out; next_ex_mem_read_out = port.ex_mem_read_out; next_ex_mem_write_out = port.ex_mem_write_out;
            next_ex_wb_src_mem_out = port.ex_wb_src_mem_out; next_ex_wb_src_pc_out = port.ex_wb_src_pc_out;
        end else begin
            next_ex_valid_out = port.if_valid_in; next_ex_pc_out = port.if_pc_in; next_ex_alu_result_out = alu_if_inst.result;
            next_ex_store_data_out = fwd_rs2; next_ex_rd_out = rd; next_ex_reg_write_out = (port.if_valid_in && cu_if.reg_write);
            next_ex_mem_size_out = funct3; next_ex_mem_read_out = (port.if_valid_in && cu_if.mem_read); next_ex_mem_write_out = (port.if_valid_in && cu_if.mem_write);
            next_ex_wb_src_mem_out = cu_if.wb_src_mem; next_ex_wb_src_pc_out = cu_if.wb_src_pc;
        end
    end

    always_ff @(posedge HCLK or negedge nRST) begin
        if (!nRST) begin
            port.ex_valid_out <= 1'b0; port.ex_pc_out <= 32'b0; port.ex_alu_result_out <= 32'b0;
            port.ex_store_data_out <= 32'b0; port.ex_rd_out <= 5'b0; port.ex_reg_write_out <= 1'b0;
            port.ex_mem_size_out <= 3'b0; port.ex_mem_read_out <= 1'b0; port.ex_mem_write_out <= 1'b0;
            port.ex_wb_src_mem_out <= 1'b0; port.ex_wb_src_pc_out <= 1'b0;
        end else begin
            port.ex_valid_out <= next_ex_valid_out; port.ex_pc_out <= next_ex_pc_out; port.ex_alu_result_out <= next_ex_alu_result_out;
            port.ex_store_data_out <= next_ex_store_data_out; port.ex_rd_out <= next_ex_rd_out; port.ex_reg_write_out <= next_ex_reg_write_out;
            port.ex_mem_size_out <= next_ex_mem_size_out; port.ex_mem_read_out <= next_ex_mem_read_out; port.ex_mem_write_out <= next_ex_mem_write_out;
            port.ex_wb_src_mem_out <= next_ex_wb_src_mem_out; port.ex_wb_src_pc_out <= next_ex_wb_src_pc_out;
        end
    end
endmodule
