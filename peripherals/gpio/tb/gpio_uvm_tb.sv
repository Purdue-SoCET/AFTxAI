module gpio_uvm_tb #(
    parameter int GPIO_WIDTH = 32
);
    import uvm_pkg::*;
    import gpio_uvm_pkg::*;

    logic pclk = 0;
    logic presetn = 0;

    always #5 pclk = ~pclk;

    apb4_if vif(pclk, presetn);
    gpio_pad_if #(32) pad_if(pclk, presetn);

    gpio_apb #(
        .GPIO_WIDTH(GPIO_WIDTH)
    ) dut (
        .pclk(pclk),
        .presetn(presetn),
        .paddr(vif.paddr),
        .psel(vif.psel),
        .penable(vif.penable),
        .pwrite(vif.pwrite),
        .pwdata(vif.pwdata),
        .pstrb(vif.pstrb),
        .pprot(vif.pprot),
        .prdata(vif.prdata),
        .pready(vif.pready),
        .pslverr(vif.pslverr),
        .gpio_in_i(pad_if.in[GPIO_WIDTH-1:0]),
        .gpio_out_o(pad_if.out[GPIO_WIDTH-1:0]),
        .gpio_oe_o(pad_if.oe[GPIO_WIDTH-1:0]),
        .gpio_pull_up_o(pad_if.pull_up[GPIO_WIDTH-1:0]),
        .gpio_pull_down_o(pad_if.pull_down[GPIO_WIDTH-1:0]),
        .irq_o(pad_if.irq)
    );

    initial begin
        uvm_config_db#(virtual apb4_if)::set(null, "*", "vif", vif);
        uvm_config_db#(virtual gpio_pad_if#(32))::set(null, "*", "pad_vif", pad_if);
        uvm_config_db#(int)::set(null, "*", "gpio_width", GPIO_WIDTH);
        run_test();
    end

    initial begin
        presetn = 0;
        pad_if.in = 0;
        #22 presetn = 1;
    end

endmodule
