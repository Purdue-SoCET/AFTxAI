module gpio_apb_wrapper #(
    parameter int GPIO_WIDTH = 32
) (
    apb_if.completer apb,

    // Physical pin interface
    input  logic [GPIO_WIDTH-1:0] gpio_in_i,
    output logic [GPIO_WIDTH-1:0] gpio_out_o,
    output logic [GPIO_WIDTH-1:0] gpio_oe_o,
    output logic [GPIO_WIDTH-1:0] gpio_pull_up_o,
    output logic [GPIO_WIDTH-1:0] gpio_pull_down_o,
    
    // Interrupt
    output logic        irq_o
);

    // Instantiate the original gpio_apb module
    gpio_apb #(
        .GPIO_WIDTH(GPIO_WIDTH)
    ) i_gpio_apb (
        .pclk    (apb.PCLK),
        .presetn (apb.PRESETn),
        
        // Pass only the lower 8 bits of PADDR to match gpio_apb expectations
        .paddr   (apb.PADDR[7:0]),
        
        .psel    (apb.PSEL),
        .penable (apb.PENABLE),
        .pwrite  (apb.PWRITE),
        .pwdata  (apb.PWDATA),
        .pstrb   (apb.PSTRB),
        .pprot   (apb.PPROT),
        
        .prdata  (apb.PRDATA),
        .pready  (apb.PREADY),
        .pslverr (apb.PSLVERR),
        
        .gpio_in_i        (gpio_in_i),
        .gpio_out_o       (gpio_out_o),
        .gpio_oe_o        (gpio_oe_o),
        .gpio_pull_up_o   (gpio_pull_up_o),
        .gpio_pull_down_o (gpio_pull_down_o),
        
        .irq_o            (irq_o)
    );

endmodule
