`ifndef GPIO_PAD_IF_SV
`define GPIO_PAD_IF_SV

interface gpio_pad_if #(parameter int WIDTH = 32) (input logic pclk, input logic presetn);
    logic [WIDTH-1:0] in;
    logic [WIDTH-1:0] out;
    logic [WIDTH-1:0] oe;
    logic [WIDTH-1:0] pull_up;
    logic [WIDTH-1:0] pull_down;
    logic             irq;
endinterface

`endif
