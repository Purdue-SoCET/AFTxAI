`timescale 1ns/1ps
module timer_fail_integration_tb;
    initial begin
        $display("Running negative failure-propagation test");
        $error("Intentional failure to test failure propagation");
        #10;
        $finish;
    end
endmodule
