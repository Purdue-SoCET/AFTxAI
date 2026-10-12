`ifndef REGFILE_IF_SV
`define REGFILE_IF_SV
interface regfile_if;
    logic [4:0] rs1, rs2, rd; logic [31:0] rdata1, rdata2, wdata; logic we; modport mp (input rs1, rs2, we, rd, wdata, output rdata1, rdata2);
endinterface
`endif
