`timescale 1ns/1ps

module execute_stage (
    input  logic clk,
    input  logic rst_n,

    // Interfaces
    fetch_exec_if.exec fe_if,
    exec_mem_if.exec   em_if,
    mem_wb_if.exec     mwb_if,

    // Control
    input  logic flush,

    // Forwarding and Hazard Interface
    output logic [4:0] rs1_addr,
    output logic [4:0] rs2_addr,
    input  logic [31:0] forward_a_val,
    input  logic [31:0] forward_b_val,
    input  logic        use_forward_a,
    input  logic        use_forward_b,

    // Branch Resolution
    output logic        branch_mispredict,
    output logic [31:0] correct_target_pc
);

    // Decode signals
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [4:0] rd;
    logic [31:0] imm;
    logic reg_write, mem_read, mem_write;
    
    // Extensions (M, C, B) placeholders
    logic is_m_ext, is_c_ext, is_b_ext;

    assign opcode = fe_if.instruction[6:0];
    assign rs1_addr = fe_if.instruction[19:15];
    assign rs2_addr = fe_if.instruction[24:20];
    assign rd = fe_if.instruction[11:7];
    assign funct3 = fe_if.instruction[14:12];
    assign funct7 = fe_if.instruction[31:25];

    // Dummy decode logic for placeholders
    assign is_m_ext = (opcode == 7'h33) && (funct7 == 7'h01);
    assign is_c_ext = 1'b0; // To be implemented with decompression
    assign is_b_ext = (opcode == 7'h33) && (funct7 == 7'h20); // Example bitmanip

    // Immediate generation (simplified)
    always_comb begin
        case(opcode)
            7'h13, 7'h03, 7'h67: imm = {{20{fe_if.instruction[31]}}, fe_if.instruction[31:20]}; // I-type
            7'h23: imm = {{20{fe_if.instruction[31]}}, fe_if.instruction[31:25], fe_if.instruction[11:7]}; // S-type
            7'h63: imm = {{20{fe_if.instruction[31]}}, fe_if.instruction[7], fe_if.instruction[30:25], fe_if.instruction[11:8], 1'b0}; // B-type
            7'h37, 7'h17: imm = {fe_if.instruction[31:12], 12'h0}; // U-type
            7'h6F: imm = {{12{fe_if.instruction[31]}}, fe_if.instruction[19:12], fe_if.instruction[20], fe_if.instruction[30:21], 1'b0}; // J-type
            default: imm = 32'h0;
        endcase
    end
    
    logic [31:0] rs1_val, rs2_val;
    logic [31:0] regfile [31:1];

    always_comb begin
        rs1_val = (rs1_addr == 0) ? 32'h0 : (use_forward_a ? forward_a_val : regfile[rs1_addr]);
        rs2_val = (rs2_addr == 0) ? 32'h0 : (use_forward_b ? forward_b_val : regfile[rs2_addr]);
    end

    // ALU (simplified)
    logic [31:0] alu_result;
    always_comb begin
        if (opcode == 7'h13 || opcode == 7'h33) alu_result = rs1_val + (opcode == 7'h13 ? imm : rs2_val); // ADD/ADDI
        else if (opcode == 7'h03 || opcode == 7'h23) alu_result = rs1_val + imm; // LOAD/STORE addr
        else alu_result = rs1_val + imm; 
    end

    // Branch execution
    logic branch_taken;
    always_comb begin
        if (opcode == 7'h63) branch_taken = (rs1_val == rs2_val); // BEQ example
        else if (opcode == 7'h6F || opcode == 7'h67) branch_taken = 1'b1; // JAL/JALR
        else branch_taken = 1'b0;
        
        branch_mispredict = fe_if.inst_valid && (branch_taken != fe_if.predicted_taken);
        correct_target_pc = branch_taken ? (fe_if.pc + imm) : (fe_if.pc + 4);
    end

    // Writeback to Regfile
    always_ff @(posedge clk) begin
        if (mwb_if.reg_write_en && mwb_if.rd_addr != 0) begin
            regfile[mwb_if.rd_addr] <= mwb_if.writeback_data;
        end
    end

    // Pipeline Register to Memory Stage
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush) begin
            em_if.pc <= 32'h0;
            em_if.alu_result <= 32'h0;
            em_if.store_data <= 32'h0;
            em_if.rd_addr <= 5'h0;
            em_if.reg_write_en <= 1'b0;
            em_if.mem_read_en <= 1'b0;
            em_if.mem_write_en <= 1'b0;
            em_if.mem_size <= 3'h2;
            em_if.valid <= 1'b0;
        end else begin
            em_if.pc <= fe_if.pc;
            em_if.alu_result <= alu_result;
            em_if.store_data <= rs2_val;
            em_if.rd_addr <= rd;
            em_if.reg_write_en <= (opcode == 7'h13 || opcode == 7'h33 || opcode == 7'h03 || opcode == 7'h37 || opcode == 7'h17 || opcode == 7'h6F || opcode == 7'h67);
            em_if.mem_read_en <= (opcode == 7'h03);
            em_if.mem_write_en <= (opcode == 7'h23);
            em_if.mem_size <= funct3;
            em_if.valid <= fe_if.inst_valid;
        end
    end

endmodule