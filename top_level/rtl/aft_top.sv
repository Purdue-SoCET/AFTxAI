`timescale 1ns/1ps

`ifndef USE_SRAM_MACRO
`define USE_SRAM_MACRO 1'b0
`endif

`ifndef SRAM_BACKEND
// 0 = OpenRAM (sky130_sram_1rw1r_64x256_8)
// 1 = SRAM22  (sram22_256x64m4w8)
`define SRAM_BACKEND 0
`endif

`ifndef USE_SYNTH_ROM
`define USE_SYNTH_ROM 1'b0
`endif

module aft_top #(
    parameter bit USE_SRAM_MACRO = `USE_SRAM_MACRO,
    parameter int SRAM_BACKEND   = `SRAM_BACKEND,
    parameter bit USE_SYNTH_ROM  = `USE_SYNTH_ROM
) (
    input  logic clk,
    input  logic rst_n,

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

    // SRAM
    sram_if.controller sram,

    // UART
    input  logic uart_rx,
    output logic uart_tx,

    // SPI0
    input  logic spi0_miso,
    output logic spi0_mosi,
    output logic spi0_sck,
    output logic spi0_cs_n,

    // I2C0
    inout  wire  i2c0_sda,
    inout  wire  i2c0_scl
);
    import aft_map_pkg::*;

    // ------------------------------------------------------------------------
    // Buses
    // ------------------------------------------------------------------------
    ahb_if mgr_ports [2](clk, rst_n);
    ahb_if sub_ports [8](clk, rst_n);

    // 0: Boot ROM
    // 1: On Chip RAM
    // 2: Off Chip SRAM
    // 3: APB Bridge (Peripheral Subsystem)
    // 4: DMA APB Bridge (dma_reg)
    // 5: CLINT
    // 6: PLIC
    // 7: UART

    localparam logic [31:0] AHB_MAP [8] = '{
        BOOT_ROM_BASE,
        ON_CHIP_RAM_BASE,
        OFF_CHIP_SRAM_BASE,
        APB_BRIDGE_BASE,
        DMA_BASE,
        CLINT_BASE,
        PLIC_BASE,
        UART_BASE
    };

    ahb_interconnect #(
        .NMANAGERS(2),
        .NSUBORDINATES(8),
        .AHB_MAP(AHB_MAP)
    ) u_ahb_matrix (
        .HCLK(clk),
        .HRESETn(rst_n),
        .manager_ports(mgr_ports),
        .subordinate_ports(sub_ports)
    );

    // ------------------------------------------------------------------------
    // RISC-V Core (Manager 0)
    // ------------------------------------------------------------------------
    bus_ahbm_if riscv_ahb();
    bus_protocol_if riscv_generic();
    riscv_if riscv_irq();

    riscv #(.BOOT_ADDR(BOOT_ROM_BASE)) u_core (
        .HCLK(clk),
        .nRST(rst_n),
        .ahbm_if(riscv_ahb.manager),
        .port(riscv_irq.mp)
    );
    
    bus_ahbm_adapter u_riscv_adapter (
        .core_bus(riscv_ahb.subordinate),
        .generic_bus(riscv_generic.protocol)
    );
    
    ahb_manager u_riscv_ahb_mgr (
        .HCLK(clk),
        .HRESETn(rst_n),
        .generic_if(riscv_generic.peripheral_vital),
        .ahb(mgr_ports[0].manager)
    );

    // ------------------------------------------------------------------------
    // DMA (Manager 1 & Subordinate 4 for config)
    // ------------------------------------------------------------------------
    logic dma_irq;
    apb_if dma_apb_if(clk, rst_n);

    ahb2apb #(
        .BASE_ADDR(DMA_BASE),
        .NWORDS(DMA_WORDS)
    ) u_dma_bridge (
        .ahbif(sub_ports[4].subordinate),
        .apbif(dma_apb_if)
    );

    dma_controller u_dma (
        .clk(clk),
        .rst_n(rst_n),
        .drq(1'b0),
        .daq(),
        .irq(dma_irq),
        .reg_bus(dma_apb_if.completer),
        .mem_bus(mgr_ports[1].manager)
    );

    // ------------------------------------------------------------------------
    // Memories
    // ------------------------------------------------------------------------
    // Boot ROM (Subordinate 0)
    bus_protocol_if rom_bus();
    ahb_subordinate #(
        .BASE_ADDR(BOOT_ROM_BASE),
        .NUM_WORDS(BOOT_ROM_WORDS)
    ) u_rom_sub (
        .HCLK(clk),
        .HRESETn(rst_n),
        .ahb(sub_ports[0].subordinate),
        .generic_if(rom_bus.protocol)
    );

    if (USE_SYNTH_ROM) begin : gen_synth_rom
        aft_boot_rom #(
            .NBYTES(BOOT_ROM_WORDS * 4)
        ) u_boot_rom (
            .clk(clk),
            .rst_n(rst_n),
            .bus(rom_bus.peripheral_vital)
        );
    end else begin : gen_ff_rom
        ff_ram #(
            .NBYTES(BOOT_ROM_WORDS * 4),
            .ROM(1'b1)
        ) u_boot_rom (
            .clk(clk),
            .rst_n(rst_n),
            .bus(rom_bus.peripheral_vital)
        );
    end

    // On-Chip RAM (Subordinate 1)
    bus_protocol_if ram_bus();
    ahb_subordinate #(
        .BASE_ADDR(ON_CHIP_RAM_BASE),
        .NUM_WORDS(ON_CHIP_RAM_WORDS)
    ) u_ram_sub (
        .HCLK(clk),
        .HRESETn(rst_n),
        .ahb(sub_ports[1].subordinate),
        .generic_if(ram_bus.protocol)
    );

    if (USE_SRAM_MACRO) begin : gen_sram_ram
        if (SRAM_BACKEND == 1) begin : gen_sram22
            sram22_sram_banked_16k u_sram_banked (
                .clk(clk),
                .rst_n(rst_n),
                .bus(ram_bus.peripheral_vital)
            );
        end else begin : gen_openram
            sky130_sram_banked_16k u_sram_banked (
                .clk(clk),
                .rst_n(rst_n),
                .bus(ram_bus.peripheral_vital)
            );
        end
    end else begin : gen_ff_ram
        ff_ram #(
            .NBYTES(ON_CHIP_RAM_WORDS * 4),
            .ROM(1'b0),
            .DUMP_FILE("memsim_ram.hex")
        ) u_onchip_ram (
            .clk(clk),
            .rst_n(rst_n),
            .bus(ram_bus.peripheral_vital)
        );
    end

    // Off-Chip SRAM Controller (Subordinate 2)
    bus_protocol_if sram_bus();
    ahb_subordinate #(
        .BASE_ADDR(OFF_CHIP_SRAM_BASE),
        .NUM_WORDS(OFF_CHIP_SRAM_WORDS)
    ) u_sram_sub (
        .HCLK(clk),
        .HRESETn(rst_n),
        .ahb(sub_ports[2].subordinate),
        .generic_if(sram_bus.protocol)
    );

    sram_controller #(
        .ADDR_WIDTH(19),
        .WAIT_CYCLES(2)
    ) u_sram_ctrl (
        .HCLK(clk),
        .nRST(rst_n),
        .bus(sram_bus.peripheral_vital),
        .sram(sram)
    );

    // UART (Subordinate 7)
    uart_if #(.ADDR_WIDTH(8), .DATA_WIDTH(32)) uart_pins(clk, rst_n);
    assign uart_pins.rx = uart_rx;
    assign uart_tx = uart_pins.tx;
    assign uart_pins.cts_n = 1'b0;

    uart #(
        .CLOCK_FREQ_HZ(50000000),
        .DEFAULT_BAUD(115200)
    ) u_uart (
        .ahb(sub_ports[7].subordinate),
        .uif(uart_pins.target)
    );

    // ------------------------------------------------------------------------
    // Peripheral Subsystem (Subordinate 3)
    // ------------------------------------------------------------------------
    logic gpio0_irq, gpio1_irq, gpio2_irq, gpio3_irq;
    logic pwm0_irq, timer0_irq;

    localparam int PERIPH_NCOMPLETERS = 9;
    
    apb_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) periph_apb_bus (
        .PCLK(clk),
        .PRESETn(rst_n)
    );
    
    // Instantiate AHB to APB bridge
    ahb2apb #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .BASE_ADDR(32'h8000_0000),
        .NWORDS(32768) // Cover up to 0x8001FFFF
    ) u_periph_bridge (
        .ahbif(sub_ports[3].subordinate),
        .apbif(periph_apb_bus.requester)
    );
    
    // APB array
    apb_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) periph_apb_slaves[PERIPH_NCOMPLETERS] (
        .PCLK(clk),
        .PRESETn(rst_n)
    );
    
    // Interconnect configuration
    localparam logic [31:0] PERIPH_APB_MAP [PERIPH_NCOMPLETERS] = '{
        32'h8000_0000, // GPIO0
        32'h8000_0100, // GPIO1
        32'h8000_0200, // GPIO2
        32'h8000_0300, // GPIO3
        32'h8000_1000, // PWM0
        32'h8000_2000, // Timer0
        IO_MUX_BASE,   // IO MUX
        SPI0_BASE,     // SPI0
        I2C0_BASE      // I2C0
    };
    
    localparam logic [31:0] PERIPH_APB_MAP_MASK [PERIPH_NCOMPLETERS] = '{
        32'hFFFF_FF00, // GPIO0: 256B
        32'hFFFF_FF00, // GPIO1: 256B
        32'hFFFF_FF00, // GPIO2: 256B
        32'hFFFF_FF00, // GPIO3: 256B
        32'hFFFF_F000, // PWM0: 4KB
        32'hFFFF_E000, // Timer0: 8KB
        32'hFFFF_F000, // IO MUX: 4KB
        32'hFFFF_F000, // SPI0: 4KB
        32'hFFFF_F000  // I2C0: 4KB
    };

    apb_interconnect #(
        .NCOMPLETERS(PERIPH_NCOMPLETERS),
        .APB_MAP(PERIPH_APB_MAP),
        .APB_MAP_MASK(PERIPH_APB_MAP_MASK)
    ) u_periph_interconnect (
        .requester(periph_apb_bus.completer),
        .completers(periph_apb_slaves)
    );
    
    logic gpio0_irq_pclk, gpio1_irq_pclk, gpio2_irq_pclk, gpio3_irq_pclk;
    logic pwm0_irq_pclk, timer0_irq_pclk;

    // Slaves instantiation
    gpio_apb_wrapper #(.GPIO_WIDTH(32)) u_gpio0 (
        .apb(periph_apb_slaves[0].completer),
        .gpio_in_i(gpio0_in), .gpio_out_o(gpio0_out), .gpio_oe_o(gpio0_oe),
        .gpio_pull_up_o(gpio0_pu), .gpio_pull_down_o(gpio0_pd),
        .irq_o(gpio0_irq_pclk)
    );
    
    gpio_apb_wrapper #(.GPIO_WIDTH(16)) u_gpio1 (
        .apb(periph_apb_slaves[1].completer),
        .gpio_in_i(gpio1_in), .gpio_out_o(gpio1_out), .gpio_oe_o(gpio1_oe),
        .gpio_pull_up_o(gpio1_pu), .gpio_pull_down_o(gpio1_pd),
        .irq_o(gpio1_irq_pclk)
    );
    
    gpio_apb_wrapper #(.GPIO_WIDTH(7)) u_gpio2 (
        .apb(periph_apb_slaves[2].completer),
        .gpio_in_i(gpio2_in), .gpio_out_o(gpio2_out), .gpio_oe_o(gpio2_oe),
        .gpio_pull_up_o(gpio2_pu), .gpio_pull_down_o(gpio2_pd),
        .irq_o(gpio2_irq_pclk)
    );
    
    gpio_apb_wrapper #(.GPIO_WIDTH(1)) u_gpio3 (
        .apb(periph_apb_slaves[3].completer),
        .gpio_in_i(gpio3_in), .gpio_out_o(gpio3_out), .gpio_oe_o(gpio3_oe),
        .gpio_pull_up_o(gpio3_pu), .gpio_pull_down_o(gpio3_pd),
        .irq_o(gpio3_irq_pclk)
    );
    
    pwm_apb_wrapper u_pwm0 (
        .apb(periph_apb_slaves[4].completer),
        .pwm_out_o(pwm_out),
        .pwm_oe_o(pwm_oe),
        .irq_o(pwm0_irq_pclk)
    );
    
    timer_apb_wrapper u_timer0 (
        .apb(periph_apb_slaves[5].completer),
        .capture_i(timer_capture),
        .irq_o(timer0_irq_pclk)
    );

    // HCLK Synchronizers for interrupts
    sync_2ff #(.WIDTH(1)) u_sync_gpio0_irq (.clk(clk), .rst_n(rst_n), .d_in(gpio0_irq_pclk), .d_out(gpio0_irq));
    sync_2ff #(.WIDTH(1)) u_sync_gpio1_irq (.clk(clk), .rst_n(rst_n), .d_in(gpio1_irq_pclk), .d_out(gpio1_irq));
    sync_2ff #(.WIDTH(1)) u_sync_gpio2_irq (.clk(clk), .rst_n(rst_n), .d_in(gpio2_irq_pclk), .d_out(gpio2_irq));
    sync_2ff #(.WIDTH(1)) u_sync_gpio3_irq (.clk(clk), .rst_n(rst_n), .d_in(gpio3_irq_pclk), .d_out(gpio3_irq));
    sync_2ff #(.WIDTH(1)) u_sync_pwm0_irq  (.clk(clk), .rst_n(rst_n), .d_in(pwm0_irq_pclk),  .d_out(pwm0_irq));
    sync_2ff #(.WIDTH(1)) u_sync_timer0_irq(.clk(clk), .rst_n(rst_n), .d_in(timer0_irq_pclk),.d_out(timer0_irq));

    digital_io_mux_apb #(
        .NUM_PINS(32),
        .NUM_BITS(2),
        .NUM_REGS(2),
        .BASE_ADDR(IO_MUX_BASE)
    ) u_io_mux (
        .pclk(clk),
        .presetn(rst_n),
        .apb(periph_apb_slaves[6].completer),
        .fsel_out()
    );

    // SPI0
    spi_if spi_pins();
    assign spi_pins.miso_in = spi0_miso;
    assign spi0_mosi = spi_pins.mosi_out;
    assign spi0_sck = spi_pins.sck_out;
    assign spi0_cs_n = spi_pins.ss_out;
    
    spi_wrapper u_spi0 (
        .pclk(clk),
        .presetn(rst_n),
        .apb(periph_apb_slaves[7].completer),
        .phy(spi_pins)
    );

    // I2C0
    i2c_if i2c_pins();
    assign i2c0_scl = i2c_pins.scl_oe ? i2c_pins.scl_o : 1'bz;
    assign i2c_pins.scl_i = i2c0_scl;
    assign i2c0_sda = i2c_pins.sda_oe ? i2c_pins.sda_o : 1'bz;
    assign i2c_pins.sda_i = i2c0_sda;

    i2c #(
        .BASE_ADDR(I2C0_BASE),
        .NWORDS(6)
    ) u_i2c0 (
        .apb(periph_apb_slaves[8].completer),
        .i2c_pins(i2c_pins.controller)
    );

    // ------------------------------------------------------------------------
    // Interrupt Controllers
    // ------------------------------------------------------------------------
    // CLINT (Subordinate 5)
    bus_protocol_if clint_bus();
    ahb_subordinate #(
        .BASE_ADDR(CLINT_BASE),
        .NUM_WORDS(CLINT_WORDS)
    ) u_clint_sub (
        .HCLK(clk),
        .HRESETn(rst_n),
        .ahb(sub_ports[5].subordinate),
        .generic_if(clint_bus.protocol)
    );
    
    clint_if clint_irq();
    clint #(.NUM_HARTS(1)) u_clint (
        .CLK(clk),
        .nRST(rst_n),
        .busif(clint_bus.peripheral_vital),
        .clif(clint_irq.clint)
    );

    assign riscv_irq.mtip = clint_irq.timer_int[0];
    assign riscv_irq.msip = clint_irq.soft_int[0];

    // PLIC (Subordinate 6)
    bus_protocol_if plic_bus();
    ahb_subordinate #(
        .BASE_ADDR(PLIC_BASE),
        .NUM_WORDS(PLIC_WORDS)
    ) u_plic_sub (
        .HCLK(clk),
        .HRESETn(rst_n),
        .ahb(sub_ports[6].subordinate),
        .generic_if(plic_bus.protocol)
    );
    
    plic_if plic_irq();
    plic u_plic (
        .clk(clk),
        .nrst(rst_n),
        .bus(plic_bus.peripheral_vital),
        .irq_if(plic_irq.plic)
    );

    assign riscv_irq.meip = plic_irq.irq_target;

    // Interrupt Mapping to PLIC
    // Source 0 is hardwired to 0 internally in plic (irq_source is [31:1])
    assign plic_irq.irq_source[IRQ_GPIO0]  = gpio0_irq;
    assign plic_irq.irq_source[IRQ_GPIO1]  = gpio1_irq;
    assign plic_irq.irq_source[IRQ_GPIO2]  = gpio2_irq;
    assign plic_irq.irq_source[IRQ_GPIO3]  = gpio3_irq;
    assign plic_irq.irq_source[IRQ_PWM0]   = pwm0_irq;
    assign plic_irq.irq_source[IRQ_TIMER0] = timer0_irq;
    assign plic_irq.irq_source[IRQ_DMA]    = dma_irq;
    
    assign plic_irq.irq_source[IRQ_SPI0] = spi_pins.irq;
    assign plic_irq.irq_source[IRQ_I2C0] = i2c_pins.irq;
    assign plic_irq.irq_source[IRQ_UART] = uart_pins.irq;
    assign plic_irq.irq_source[IRQ_GPIO_BOOT] = 1'b0;
    
    generate
        for (genvar i = 12; i < 32; i++) begin : gen_plic_tieoff
            assign plic_irq.irq_source[i] = 1'b0;
        end
    endgenerate

endmodule
