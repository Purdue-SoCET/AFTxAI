`ifndef RISCV_IF_SV
`define RISCV_IF_SV
interface riscv_if;
    logic mtip;
    logic msip;
    logic meip;
    modport mp(input mtip, msip, meip);
endinterface
`endif
