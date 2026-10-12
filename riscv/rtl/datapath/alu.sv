`timescale 1ns/1ps
module alu(alu_if.mp port);
    always_comb begin
        case (port.alu_op)
            4'd0: port.result = port.a + port.b;
            4'd1: port.result = port.a - port.b;
            4'd2: port.result = port.a << port.b[4:0];
            4'd3: port.result = {31'b0, $signed(port.a) < $signed(port.b)};
            4'd4: port.result = {31'b0, port.a < port.b};
            4'd5: port.result = port.a ^ port.b;
            4'd6: port.result = port.a >> port.b[4:0];
            4'd7: port.result = $signed(port.a) >>> port.b[4:0];
            4'd8: port.result = port.a | port.b;
            4'd9: port.result = port.a & port.b;
            4'd10: port.result = port.b;
            default: port.result = 32'b0;
        endcase
        port.zero = (port.result == 32'b0);
    end
endmodule
