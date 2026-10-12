`timescale 1ns/1ps
module forwarding_unit(forwarding_unit_if.mp port);
    assign port.fwd_a = (port.wb_reg_write && (port.wb_rd != 5'b0) && (port.wb_rd == port.ex_rs1));
    assign port.fwd_b = (port.wb_reg_write && (port.wb_rd != 5'b0) && (port.wb_rd == port.ex_rs2));
endmodule
