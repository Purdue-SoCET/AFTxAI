`timescale 1ns/1ps

module control_unit (
    input  logic [6:0] opcode,
    input  logic [2:0] funct3,
    input  logic [6:0] funct7,
    
    output logic       reg_write,
    output logic [2:0] imm_src,
    output logic       alu_src_a_pc,
    output logic       alu_src_b_imm,
    output logic [3:0] alu_op,
    output logic       is_branch,
    output logic       is_jal,
    output logic       is_jalr,
    output logic       mem_read,
    output logic       mem_write,
    output logic [2:0] mem_size,
    output logic       wb_src_mem,
    output logic       wb_src_pc,
    output logic       illegal_instr
);

    // -- Opcodes --
    localparam [6:0] OPC_LOAD   = 7'b0000011;
    localparam [6:0] OPC_IMM    = 7'b0010011;
    localparam [6:0] OPC_AUIPC  = 7'b0010111;
    localparam [6:0] OPC_STORE  = 7'b0100011;
    localparam [6:0] OPC_OP     = 7'b0110011;
    localparam [6:0] OPC_LUI    = 7'b0110111;
    localparam [6:0] OPC_BRANCH = 7'b1100011;
    localparam [6:0] OPC_JALR   = 7'b1100111;
    localparam [6:0] OPC_JAL    = 7'b1101111;

    always_comb begin
        reg_write     = 1'b0;
        imm_src       = 3'd0;
        alu_src_a_pc  = 1'b0;
        alu_src_b_imm = 1'b0;
        alu_op        = 4'd0;
        is_branch     = 1'b0;
        is_jal        = 1'b0;
        is_jalr       = 1'b0;
        mem_read      = 1'b0;
        mem_write     = 1'b0;
        mem_size      = funct3;
        wb_src_mem    = 1'b0;
        wb_src_pc     = 1'b0;
        illegal_instr = 1'b0;

        case (opcode)
            OPC_LUI: begin
                reg_write = 1'b1;
                imm_src = 3'd3; // U
                alu_src_b_imm = 1'b1;
                alu_op = 4'd10; // PASS_B
            end
            OPC_AUIPC: begin
                reg_write = 1'b1;
                imm_src = 3'd3; // U
                alu_src_a_pc = 1'b1;
                alu_src_b_imm = 1'b1;
                alu_op = 4'd0; // ADD
            end
            OPC_JAL: begin
                reg_write = 1'b1;
                imm_src = 3'd4; // J
                wb_src_pc = 1'b1;
                is_jal = 1'b1;
            end
            OPC_JALR: begin
                reg_write = 1'b1;
                imm_src = 3'd0; // I
                wb_src_pc = 1'b1;
                alu_src_b_imm = 1'b1;
                alu_op = 4'd0; // ADD
                is_jalr = 1'b1;
            end
            OPC_BRANCH: begin
                imm_src = 3'd2; // B
                is_branch = 1'b1;
            end
            OPC_LOAD: begin
                reg_write = 1'b1;
                imm_src = 3'd0; // I
                mem_read = 1'b1;
                wb_src_mem = 1'b1;
                alu_src_b_imm = 1'b1;
                alu_op = 4'd0; // ADD
            end
            OPC_STORE: begin
                imm_src = 3'd1; // S
                mem_write = 1'b1;
                alu_src_b_imm = 1'b1;
                alu_op = 4'd0; // ADD
            end
            OPC_IMM: begin
                reg_write = 1'b1;
                imm_src = 3'd0; // I
                alu_src_b_imm = 1'b1;
                case (funct3)
                    3'b000: alu_op = 4'd0; // ADD
                    3'b010: alu_op = 4'd3; // SLT
                    3'b011: alu_op = 4'd4; // SLTU
                    3'b100: alu_op = 4'd5; // XOR
                    3'b110: alu_op = 4'd8; // OR
                    3'b111: alu_op = 4'd9; // AND
                    3'b001: alu_op = 4'd2; // SLL
                    3'b101: alu_op = funct7[5] ? 4'd7 : 4'd6; // SRA : SRL
                endcase
            end
            OPC_OP: begin
                reg_write = 1'b1;
                case (funct3)
                    3'b000: alu_op = funct7[5] ? 4'd1 : 4'd0; // SUB : ADD
                    3'b010: alu_op = 4'd3; // SLT
                    3'b011: alu_op = 4'd4; // SLTU
                    3'b100: alu_op = 4'd5; // XOR
                    3'b110: alu_op = 4'd8; // OR
                    3'b111: alu_op = 4'd9; // AND
                    3'b001: alu_op = 4'd2; // SLL
                    3'b101: alu_op = funct7[5] ? 4'd7 : 4'd6; // SRA : SRL
                endcase
            end
            7'b0000000: begin
                // Bubble / NOP
            end
            default: illegal_instr = 1'b1;
        endcase
    end
endmodule
