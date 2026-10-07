import riscv_pkg::*;

module ext_a_decoder #(
  parameter int RV32E = 0
)(
  input  logic [31:0]     instr,
  output decoded_instr_t  dec
);

  logic [6:0] op;
  logic [2:0] funct3;
  logic [4:0] amo_funct5;

  always_comb begin
    dec = '0;
    op = instr[6:0];
    funct3 = instr[14:12];
    amo_funct5 = instr[31:27];
    
    dec.opcode = opcode_t'(op);
    dec.rs1 = instr[19:15];
    dec.rs2 = instr[24:20];
    dec.rd  = instr[11:7];
    
    if (RV32E && (dec.rs1 >= 16 || dec.rs2 >= 16 || dec.rd >= 16)) begin
      dec.is_illegal = 1'b1;
    end

    if (dec.opcode == OPC_AMO && funct3 == 3'b010) begin
      dec.valid = 1'b1;
      dec.uses_rs1 = 1'b1;
      dec.uses_rd = 1'b1;
      dec.is_amo = 1'b1;
      // All AMOs use base address from RS1, so ALU_ADD with 0 is useful for address calc
      dec.exec_op = ALU_ADD; 
      
      case (amo_funct5)
        5'b00010: begin // LR.W
          if (dec.rs2 != 5'd0) dec.valid = 1'b0;
        end
        5'b00011: dec.uses_rs2 = 1'b1; // SC.W
        5'b00001: dec.uses_rs2 = 1'b1; // AMOSWAP.W
        5'b00000: dec.uses_rs2 = 1'b1; // AMOADD.W
        5'b00100: dec.uses_rs2 = 1'b1; // AMOXOR.W
        5'b01100: dec.uses_rs2 = 1'b1; // AMOAND.W
        5'b01000: dec.uses_rs2 = 1'b1; // AMOOR.W
        5'b10000: dec.uses_rs2 = 1'b1; // AMOMIN.W
        5'b10100: dec.uses_rs2 = 1'b1; // AMOMAX.W
        5'b11000: dec.uses_rs2 = 1'b1; // AMOMINU.W
        5'b11100: dec.uses_rs2 = 1'b1; // AMOMAXU.W
        default: dec.valid = 1'b0;
      endcase
    end else begin
      dec.valid = 1'b0;
    end
    
    if (!dec.valid) begin
      dec.is_illegal = 1'b1;
    end
  end
endmodule
