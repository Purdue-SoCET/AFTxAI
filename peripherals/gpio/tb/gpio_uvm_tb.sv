module gpio_uvm_tb;
    import uvm_pkg::*;
    import gpio_uvm_pkg::*;

    logic pclk = 0;
    logic presetn = 0;

    always #5 pclk = ~pclk;

    apb4_if vif(pclk, presetn);

    logic [31:0] gpio_in_i = '0;
    logic [31:0] gpio_out_o;
    logic [31:0] gpio_oe_o;
    logic [31:0] gpio_pull_up_o;
    logic [31:0] gpio_pull_down_o;
    logic        irq_o;

    gpio_apb #(
        .GPIO_WIDTH(32)
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
        .gpio_in_i(gpio_in_i),
        .gpio_out_o(gpio_out_o),
        .gpio_oe_o(gpio_oe_o),
        .gpio_pull_up_o(gpio_pull_up_o),
        .gpio_pull_down_o(gpio_pull_down_o),
        .irq_o(irq_o)
    );

    initial begin
        uvm_config_db#(virtual apb4_if)::set(null, "*", "vif", vif);
        run_test();
    end

    initial begin
        presetn = 0;
        #20 presetn = 1;
    end

endmodule
