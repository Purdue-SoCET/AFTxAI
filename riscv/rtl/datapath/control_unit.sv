`timescale 1ns/1ps
module control_unit(control_unit_if.mp port);
    always_comb begin
        port.reg_write = 1'b0;
        port.imm_src = 3'd0;
        port.alu_src_a_pc = 1'b0;
        port.alu_src_b_imm = 1'b0;
        port.alu_op = 4'd0;
        port.is_branch = 1'b0;
        port.is_jal = 1'b0;
        port.is_jalr = 1'b0;
        port.mem_read = 1'b0;
        port.mem_write = 1'b0;
        port.mem_size = port.funct3;
        port.wb_src_mem = 1'b0;
        port.wb_src_pc = 1'b0;
        port.illegal_instr = 1'b0;

        case (port.opcode)
            7'b0110111: begin port.reg_write = 1'b1; port.imm_src = 3'd3; port.alu_src_b_imm = 1'b1; port.alu_op = 4'd10; end
            7'b0010111: begin port.reg_write = 1'b1; port.imm_src = 3'd3; port.alu_src_a_pc = 1'b1; port.alu_src_b_imm = 1'b1; port.alu_op = 4'd0; end
            7'b1101111: begin port.reg_write = 1'b1; port.imm_src = 3'd4; port.wb_src_pc = 1'b1; port.is_jal = 1'b1; end
            7'b1100111: begin port.reg_write = 1'b1; port.imm_src = 3'd0; port.wb_src_pc = 1'b1; port.alu_src_b_imm = 1'b1; port.alu_op = 4'd0; port.is_jalr = 1'b1; end
            7'b1100011: begin port.imm_src = 3'd2; port.is_branch = 1'b1; end
            7'b0000011: begin port.reg_write = 1'b1; port.imm_src = 3'd0; port.mem_read = 1'b1; port.wb_src_mem = 1'b1; port.alu_src_b_imm = 1'b1; port.alu_op = 4'd0; end
            7'b0100011: begin port.imm_src = 3'd1; port.mem_write = 1'b1; port.alu_src_b_imm = 1'b1; port.alu_op = 4'd0; end
            7'b0010011: begin
                port.reg_write = 1'b1; port.imm_src = 3'd0; port.alu_src_b_imm = 1'b1;
                case (port.funct3)
                    3'b000: port.alu_op = 4'd0; 3'b010: port.alu_op = 4'd3; 3'b011: port.alu_op = 4'd4; 3'b100: port.alu_op = 4'd5;
                    3'b110: port.alu_op = 4'd8; 3'b111: port.alu_op = 4'd9; 3'b001: port.alu_op = 4'd2; 3'b101: port.alu_op = port.funct7[5] ? 4'd7 : 4'd6;
                endcase
            end
            7'b0110011: begin
                port.reg_write = 1'b1;
                case (port.funct3)
                    3'b000: port.alu_op = port.funct7[5] ? 4'd1 : 4'd0; 3'b010: port.alu_op = 4'd3; 3'b011: port.alu_op = 4'd4; 3'b100: port.alu_op = 4'd5;
                    3'b110: port.alu_op = 4'd8; 3'b111: port.alu_op = 4'd9; 3'b001: port.alu_op = 4'd2; 3'b101: port.alu_op = port.funct7[5] ? 4'd7 : 4'd6;
                endcase
            end
            7'b0000000: ; // NOP
            default: port.illegal_instr = 1'b1;
        endcase
    end
endmodule
