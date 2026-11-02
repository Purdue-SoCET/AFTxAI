`timescale 1ns/1ps
module tb;
    logic pclk;
    logic presetn;

    logic [11:0] paddr;
    logic psel;
    logic penable;
    logic pwrite;
    logic [31:0] pwdata;
    logic [3:0] pstrb;
    logic [2:0] pprot;
    logic [31:0] prdata;
    logic pready;
    logic pslverr;

    logic [3:0] pwm_out_o;
    logic [3:0] pwm_oe_o;
    logic irq_o;

    pwm_core #(
        .PWM_CHANNELS(4),
        .ADDR_WIDTH(12),
        .DATA_WIDTH(32)
    ) dut (.*);

    initial begin
        pclk = 0;
        forever #40 pclk = ~pclk;
    end

    task apb_write(input logic [11:0] addr, input logic [31:0] data, input logic [3:0] strb, output logic err);
        @(posedge pclk);
        paddr <= addr;
        psel <= 1;
        penable <= 0;
        pwrite <= 1;
        pwdata <= data;
        pstrb <= strb;
        pprot <= 3'b000;
        @(posedge pclk);
        penable <= 1;
        #1;
        while (!pready) begin
            @(posedge pclk);
            #1;
        end
        err = pslverr;
        $display("Time %0t: err sampled as %0d, pslverr=%b, ch_en=%b, pwdata=%0d", $time, err, pslverr, dut.ch_en[0], pwdata);
        @(posedge pclk);
        psel <= 0;
        penable <= 0;
    endtask

    initial begin
        logic err;
        presetn = 0; psel = 0; penable = 0; pwrite = 0; pstrb = 0; pwdata = 0; paddr = 0; pprot = 0;
        repeat(5) @(posedge pclk);
        presetn = 1;
        repeat(5) @(posedge pclk);

        apb_write(12'h004, 32'd10, 4'hF, err);
        apb_write(12'h008, 32'd5, 4'hF, err);
        apb_write(12'h000, 32'd1, 4'hF, err); // EN=1, POL=0
        apb_write(12'h000, 32'd3, 4'hF, err); // EN=1, POL=1
        $finish;
    end
endmodule
