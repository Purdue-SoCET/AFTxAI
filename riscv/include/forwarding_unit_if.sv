`ifndef FORWARDING_UNIT_IF_SV
`define FORWARDING_UNIT_IF_SV
interface forwarding_unit_if;
    logic [4:0] ex_rs1, ex_rs2, wb_rd; logic wb_reg_write, fwd_a, fwd_b; modport mp (input ex_rs1, ex_rs2, wb_reg_write, wb_rd, output fwd_a, fwd_b);
endinterface
`endif
