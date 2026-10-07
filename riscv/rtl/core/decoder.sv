import riscv_pkg::*;

module decoder #(
  parameter int RV32E = 0,
  parameter int EXT_A = 1
)(
  input  logic [31:0]     instr,
  output decoded_instr_t  dec
);

  decoded_instr_t base_dec;
  
  base_decoder #(
    .RV32E(RV32E)
  ) u_base_dec (
    .instr(instr),
    .dec(base_dec)
  );

  generate
    if (EXT_A) begin : gen_ext_a
      decoded_instr_t a_dec;
      
      ext_a_decoder #(
        .RV32E(RV32E)
      ) u_ext_a_dec (
        .instr(instr),
        .dec(a_dec)
      );
      
      always_comb begin
        if (a_dec.valid) begin
          dec = a_dec;
          dec.is_illegal = 1'b0;
        end else begin
          dec = base_dec;
        end
      end
    end else begin : gen_no_ext_a
      always_comb begin
        dec = base_dec;
      end
    end
  endgenerate

endmodule
