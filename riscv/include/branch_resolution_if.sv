`ifndef BRANCH_RESOLUTION_IF_SV
`define BRANCH_RESOLUTION_IF_SV
interface branch_resolution_if;
    logic [31:0] rs1_data, rs2_data; logic [2:0] funct3; logic branch_taken; modport mp (input rs1_data, rs2_data, funct3, output branch_taken);
endinterface
`endif
