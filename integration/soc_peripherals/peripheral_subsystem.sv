`include "ahb_if.sv"
`include "apb_if.sv"

module peripheral_subsystem (
    input  logic hclk,
    input  logic hresetn,
    input  logic pclk,
    input  logic presetn,
    
    ahb_if.subordinate ahb,
    
    // GPIO 0
    input  logic [31:0] gpio0_in,
    output logic [31:0] gpio0_out,
    output logic [31:0] gpio0_oe,
    output logic [31:0] gpio0_pu,
    output logic [31:0] gpio0_pd,
    
    // GPIO 1
    input  logic [15:0] gpio1_in,
    output logic [15:0] gpio1_out,
    output logic [15:0] gpio1_oe,
    output logic [15:0] gpio1_pu,
    output logic [15:0] gpio1_pd,

    // GPIO 2
    input  logic [6:0] gpio2_in,
    output logic [6:0] gpio2_out,
    output logic [6:0] gpio2_oe,
    output logic [6:0] gpio2_pu,
    output logic [6:0] gpio2_pd,

    // GPIO 3
    input  logic [0:0] gpio3_in,
    output logic [0:0] gpio3_out,
    output logic [0:0] gpio3_oe,
    output logic [0:0] gpio3_pu,
    output logic [0:0] gpio3_pd,
    
    // PWM
    output logic [3:0] pwm_out,
    output logic [3:0] pwm_oe,
    
    // Timer
    input  logic timer_capture,
    
    // Interrupts (Synchronized to HCLK domain)
    output logic gpio0_irq,
    output logic gpio1_irq,
    output logic gpio2_irq,
    output logic gpio3_irq,
    output logic pwm0_irq,
    output logic timer0_irq
);

    // Number of APB completers: GPIO0-3, PWM0, Timer0, IO_MUX
    localparam int NCOMPLETERS = 7;
    
    apb_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) apb_bus (
        .PCLK(pclk),
        .PRESETn(presetn)
    );
    
    // Instantiate AHB to APB bridge
    ahb2apb #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .BASE_ADDR(32'h8000_0000),
        .NWORDS(8192) // Cover up to 0x7FFF
    ) u_bridge (
        .ahbif(ahb),
        .apbif(apb_bus.requester)
    );
    
    // APB array
    apb_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) apb_slaves[NCOMPLETERS] (
        .PCLK(pclk),
        .PRESETn(presetn)
    );
    
    // Interconnect configuration
`ifdef TEST_OVERLAP
    localparam logic [31:0] APB_MAP [NCOMPLETERS] = '{
        32'h0000_0000,
        32'h0000_0100,
        32'h0000_0200,
        32'h0000_0300,
        32'h0000_1000,
        32'h0000_2000,
        32'h0000_2000  // OVERLAP IO MUX WITH TIMER0!
    };
`else
`ifdef TEST_OVERLAP
    localparam logic [31:0] APB_MAP [NCOMPLETERS] = '{
        32'h0000_0000, // GPIO0
        32'h0000_0100, // GPIO1
        32'h0000_0200, // GPIO2
        32'h0000_0300, // GPIO3
        32'h0000_1000, // PWM0
        32'h0000_2000, // Timer0
        32'h0000_2000  // OVERLAP IO MUX WITH TIMER0
    };
`else
    localparam logic [31:0] APB_MAP [NCOMPLETERS] = '{
        32'h0000_0000, // GPIO0
        32'h0000_0100, // GPIO1
        32'h0000_0200, // GPIO2
        32'h0000_0300, // GPIO3
        32'h0000_1000, // PWM0
        32'h0000_2000, // Timer0
        32'h0000_6000  // IO MUX
    };
`endif
`endif
    
    localparam logic [31:0] APB_MAP_MASK [NCOMPLETERS] = '{
        32'hFFFF_FF00, // GPIO0: 256B
        32'hFFFF_FF00, // GPIO1: 256B
        32'hFFFF_FF00, // GPIO2: 256B
        32'hFFFF_FF00, // GPIO3: 256B
        32'hFFFF_F000, // PWM0: 4KB
        32'hFFFF_E000, // Timer0: 8KB
        32'hFFFF_F000  // IO MUX: 4KB
    };

    apb_interconnect #(
        .NCOMPLETERS(NCOMPLETERS),
        .APB_MAP(APB_MAP),
        .APB_MAP_MASK(APB_MAP_MASK)
    ) u_interconnect (
        .requester(apb_bus.completer),
        .completers(apb_slaves)
    );
    
    logic gpio0_irq_pclk, gpio1_irq_pclk, gpio2_irq_pclk, gpio3_irq_pclk;
    logic pwm0_irq_pclk, timer0_irq_pclk;

    // Slaves instantiation
    gpio_apb_wrapper #(.GPIO_WIDTH(32)) u_gpio0 (
        .apb(apb_slaves[0].completer),
        .gpio_in_i(gpio0_in), .gpio_out_o(gpio0_out), .gpio_oe_o(gpio0_oe),
        .gpio_pull_up_o(gpio0_pu), .gpio_pull_down_o(gpio0_pd),
        .irq_o(gpio0_irq_pclk)
    );
    
    gpio_apb_wrapper #(.GPIO_WIDTH(16)) u_gpio1 (
        .apb(apb_slaves[1].completer),
        .gpio_in_i(gpio1_in), .gpio_out_o(gpio1_out), .gpio_oe_o(gpio1_oe),
        .gpio_pull_up_o(gpio1_pu), .gpio_pull_down_o(gpio1_pd),
        .irq_o(gpio1_irq_pclk)
    );
    
    gpio_apb_wrapper #(.GPIO_WIDTH(7)) u_gpio2 (
        .apb(apb_slaves[2].completer),
        .gpio_in_i(gpio2_in), .gpio_out_o(gpio2_out), .gpio_oe_o(gpio2_oe),
        .gpio_pull_up_o(gpio2_pu), .gpio_pull_down_o(gpio2_pd),
        .irq_o(gpio2_irq_pclk)
    );
    
    gpio_apb_wrapper #(.GPIO_WIDTH(1)) u_gpio3 (
        .apb(apb_slaves[3].completer),
        .gpio_in_i(gpio3_in), .gpio_out_o(gpio3_out), .gpio_oe_o(gpio3_oe),
        .gpio_pull_up_o(gpio3_pu), .gpio_pull_down_o(gpio3_pd),
        .irq_o(gpio3_irq_pclk)
    );
    
    pwm_apb_wrapper u_pwm0 (
        .apb(apb_slaves[4].completer),
        .pwm_out_o(pwm_out),
        .pwm_oe_o(pwm_oe),
        .irq_o(pwm0_irq_pclk)
    );
    
    timer_apb_wrapper u_timer0 (
        .apb(apb_slaves[5].completer),
        .capture_i(timer_capture),
        .irq_o(timer0_irq_pclk)
    );

    // HCLK Synchronizers for interrupts
    sync_2ff #(.WIDTH(1)) u_sync_gpio0_irq (.clk(hclk), .rst_n(hresetn), .d_in(gpio0_irq_pclk), .d_out(gpio0_irq));
    sync_2ff #(.WIDTH(1)) u_sync_gpio1_irq (.clk(hclk), .rst_n(hresetn), .d_in(gpio1_irq_pclk), .d_out(gpio1_irq));
    sync_2ff #(.WIDTH(1)) u_sync_gpio2_irq (.clk(hclk), .rst_n(hresetn), .d_in(gpio2_irq_pclk), .d_out(gpio2_irq));
    sync_2ff #(.WIDTH(1)) u_sync_gpio3_irq (.clk(hclk), .rst_n(hresetn), .d_in(gpio3_irq_pclk), .d_out(gpio3_irq));
    sync_2ff #(.WIDTH(1)) u_sync_pwm0_irq  (.clk(hclk), .rst_n(hresetn), .d_in(pwm0_irq_pclk),  .d_out(pwm0_irq));
    sync_2ff #(.WIDTH(1)) u_sync_timer0_irq(.clk(hclk), .rst_n(hresetn), .d_in(timer0_irq_pclk),.d_out(timer0_irq));

    // Provide default tie-offs for IO Mux since we're only instantiating its APB register component for test
    // or we can instantiate the whole digital_io_mux if we want.
    // Wait, let's just terminate it for now if we don't need its full pads, or we can instantiate digital_io_mux_apb directly
    digital_io_mux_apb #(
        .NUM_PINS(32),
        .NUM_BITS(2),
        .NUM_REGS(2),
        .BASE_ADDR(32'h6000)
    ) u_io_mux (
        .pclk(pclk),
        .presetn(presetn),
        .apb(apb_slaves[6].completer),
        .fsel_out()
    );

endmodule
