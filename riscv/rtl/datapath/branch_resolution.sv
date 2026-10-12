`timescale 1ns/1ps
module branch_resolution(branch_resolution_if.mp port);
    always_comb begin
        case (port.funct3)
            3'b000: port.branch_taken = (port.rs1_data == port.rs2_data);
            3'b001: port.branch_taken = (port.rs1_data != port.rs2_data);
            3'b100: port.branch_taken = ($signed(port.rs1_data) < $signed(port.rs2_data));
            3'b101: port.branch_taken = ($signed(port.rs1_data) >= $signed(port.rs2_data));
            3'b110: port.branch_taken = (port.rs1_data < port.rs2_data);
            3'b111: port.branch_taken = (port.rs1_data >= port.rs2_data);
            default: port.branch_taken = 1'b0;
        endcase
    end
endmodule
