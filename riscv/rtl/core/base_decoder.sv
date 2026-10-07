import riscv_pkg::*;

module base_decoder #(
  parameter int RV32E = 0
)(
  input  logic [31:0]     instr,
  output decoded_instr_t  dec
);

  logic [6:0] op;
  logic [2:0] funct3;
  logic [6:0] funct7;

  always_comb begin
    // Default assignments
    dec = '0;
    op = instr[6:0];
    funct3 = instr[14:12];
    funct7 = instr[31:25];
    
    dec.opcode = opcode_t'(op);
    dec.rs1 = instr[19:15];
    dec.rs2 = instr[24:20];
    dec.rd  = instr[11:7];
    
    // Validate RV32E boundary
    if (RV32E && (dec.rs1 >= 16 || dec.rs2 >= 16 || dec.rd >= 16)) begin
      dec.is_illegal = 1'b1;
    end

    // Instruction Decode
    case (dec.opcode)
      OPC_LUI, OPC_AUIPC: begin
        dec.valid = 1'b1;
        dec.uses_rd = 1'b1;
        dec.imm = {instr[31:12], 12'd0}; // U-type
        dec.exec_op = ALU_ADD;
      end
      
      OPC_JAL: begin
        dec.valid = 1'b1;
        dec.uses_rd = 1'b1;
        dec.is_jump = 1'b1;
        dec.imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0}; // J-type
        dec.exec_op = ALU_ADD;
      end
      
      OPC_JALR: begin
        dec.valid = (funct3 == 3'b000);
        dec.uses_rs1 = 1'b1;
        dec.uses_rd = 1'b1;
        dec.is_jump = 1'b1;
        dec.imm = {{20{instr[31]}}, instr[31:20]}; // I-type
        dec.exec_op = ALU_ADD;
      end
      
      OPC_BRANCH: begin
        dec.valid = (funct3 != 3'b010 && funct3 != 3'b011);
        dec.uses_rs1 = 1'b1;
        dec.uses_rs2 = 1'b1;
        dec.is_branch = 1'b1;
        dec.imm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0}; // B-type
      end
      
      OPC_LOAD: begin
        dec.valid = (funct3 != 3'b011 && funct3 != 3'b110 && funct3 != 3'b111);
        dec.uses_rs1 = 1'b1;
        dec.uses_rd = 1'b1;
        dec.is_load = 1'b1;
        dec.imm = {{20{instr[31]}}, instr[31:20]}; // I-type
        dec.exec_op = ALU_ADD;
      end
      
      OPC_STORE: begin
        dec.valid = (funct3 == 3'b000 || funct3 == 3'b001 || funct3 == 3'b010);
        dec.uses_rs1 = 1'b1;
        dec.uses_rs2 = 1'b1;
        dec.is_store = 1'b1;
        dec.imm = {{20{instr[31]}}, instr[31:25], instr[11:7]}; // S-type
        dec.exec_op = ALU_ADD;
      end
      
      OPC_OP_IMM: begin
        dec.valid = 1'b1;
        dec.uses_rs1 = 1'b1;
        dec.uses_rd = 1'b1;
        dec.imm = {{20{instr[31]}}, instr[31:20]}; // I-type
        
        case (funct3)
          3'b000: dec.exec_op = ALU_ADD;
          3'b010: dec.exec_op = ALU_SLT;
          3'b011: dec.exec_op = ALU_SLTU;
          3'b100: dec.exec_op = ALU_XOR;
          3'b110: dec.exec_op = ALU_OR;
          3'b111: dec.exec_op = ALU_AND;
          3'b001: begin
            dec.exec_op = ALU_SLL;
            if (instr[31:25] != 7'b0000000) dec.valid = 1'b0;
          end
          3'b101: begin
            if (instr[31:25] == 7'b0000000) dec.exec_op = ALU_SRL;
            else if (instr[31:25] == 7'b0100000) dec.exec_op = ALU_SRA;
            else dec.valid = 1'b0;
          end
        endcase
      end
      
      OPC_OP: begin
        dec.valid = 1'b1;
        dec.uses_rs1 = 1'b1;
        dec.uses_rs2 = 1'b1;
        dec.uses_rd = 1'b1;
        
        case (funct3)
          3'b000: dec.exec_op = (funct7 == 7'b0100000) ? ALU_SUB : ALU_ADD;
          3'b001: dec.exec_op = ALU_SLL;
          3'b010: dec.exec_op = ALU_SLT;
          3'b011: dec.exec_op = ALU_SLTU;
          3'b100: dec.exec_op = ALU_XOR;
          3'b101: dec.exec_op = (funct7 == 7'b0100000) ? ALU_SRA : ALU_SRL;
          3'b110: dec.exec_op = ALU_OR;
          3'b111: dec.exec_op = ALU_AND;
        endcase
        if (funct7 != 7'b0000000 && funct7 != 7'b0100000) dec.valid = 1'b0;
      end
      
      OPC_SYSTEM: begin
        // CSR and Trap stubs
        if (funct3 != 3'b000) begin
          dec.valid = 1'b1;
          dec.is_csr = 1'b1;
          dec.uses_rd = 1'b1;
          dec.imm = {27'd0, instr[19:15]}; // zimm
        end else begin
          dec.valid = 1'b1; // ecall/ebreak/mret
        end
      end
      
      OPC_MISC_MEM: begin
        dec.valid = 1'b1; // FENCE, FENCE.I (No-ops handled in execution/hazard)
      end
      
      default: begin
        dec.valid = 1'b0;
      end
    endcase

    if (!dec.valid) begin
      dec.is_illegal = 1'b1;
    end
  end

endmodule
