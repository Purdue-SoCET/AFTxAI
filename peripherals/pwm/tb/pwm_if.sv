`ifndef PWM_IF_SV
`define PWM_IF_SV

interface pwm_if #(parameter int PWM_CHANNELS = 4) (
    input logic pclk,
    input logic presetn
);
    logic [PWM_CHANNELS-1:0] pwm_out_o;
    logic [PWM_CHANNELS-1:0] pwm_oe_o;
    logic                    irq_o;
endinterface

`endif
