`timescale 1ns/1ps
module imm_gen(imm_gen_if.mp port);
    always_comb begin
        case (port.imm_src)
            3'd0: port.imm = {{20{port.instr[31]}}, port.instr[31:20]};
            3'd1: port.imm = {{20{port.instr[31]}}, port.instr[31:25], port.instr[11:7]};
            3'd2: port.imm = {{20{port.instr[31]}}, port.instr[7], port.instr[30:25], port.instr[11:8], 1'b0};
            3'd3: port.imm = {port.instr[31:12], 12'b0};
            3'd4: port.imm = {{12{port.instr[31]}}, port.instr[19:12], port.instr[20], port.instr[30:21], 1'b0};
            default: port.imm = 32'b0;
        endcase
    end
endmodule
