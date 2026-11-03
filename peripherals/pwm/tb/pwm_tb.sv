`ifndef PWM_TB_SV
`define PWM_TB_SV

`include "uvm_macros.svh"
import uvm_pkg::*;
import pwm_uvm_pkg::*;

module pwm_tb;

    logic pclk;
    logic presetn;

    // Clock generation
    initial begin
        pclk = 0;
        forever #40 pclk = ~pclk; // 12.5 MHz
    end

    // Reset generation
    initial begin
        presetn = 0;
        #100;
        presetn = 1;
    end

    apb4_if #(.ADDR_WIDTH(12), .DATA_WIDTH(32)) apb_vif(.pclk(pclk), .presetn(presetn));
    pwm_if  #(.PWM_CHANNELS(4)) pwm_vif(.pclk(pclk), .presetn(presetn));

    pwm_core #(
        .PWM_CHANNELS(4),
        .ADDR_WIDTH(12),
        .DATA_WIDTH(32)
    ) dut (
        .pclk(pclk),
        .presetn(presetn),
        .paddr(apb_vif.paddr),
        .psel(apb_vif.psel),
        .penable(apb_vif.penable),
        .pwrite(apb_vif.pwrite),
        .pwdata(apb_vif.pwdata),
        .pstrb(apb_vif.pstrb),
        .pprot(apb_vif.pprot),
        .prdata(apb_vif.prdata),
        .pready(apb_vif.pready),
        .pslverr(apb_vif.pslverr),
        .pwm_out_o(pwm_vif.pwm_out_o),
        .pwm_oe_o(pwm_vif.pwm_oe_o),
        .irq_o(pwm_vif.irq_o)
    );

    initial begin
        uvm_config_db#(virtual apb4_if#(.ADDR_WIDTH(12), .DATA_WIDTH(32)))::set(null, "*", "apb_vif", apb_vif);
        uvm_config_db#(virtual pwm_if#(.PWM_CHANNELS(4)))::set(null, "*", "pwm_vif", pwm_vif);
        run_test();
    end

endmodule

`endif
