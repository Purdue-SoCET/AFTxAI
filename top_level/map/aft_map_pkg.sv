`ifndef AFT_MAP_PKG_SV
`define AFT_MAP_PKG_SV

package aft_map_pkg;

    // AHB Regions
    localparam logic [31:0] BOOT_ROM_BASE = 32'h00000400;
    localparam int BOOT_ROM_WORDS = 1024;
    localparam logic [31:0] ON_CHIP_RAM_BASE = 32'h00008400;
    localparam int ON_CHIP_RAM_WORDS = 4096;
    localparam logic [31:0] OFF_CHIP_SRAM_BASE = 32'h00020000;
    localparam int OFF_CHIP_SRAM_WORDS = 524288;
    localparam logic [31:0] APB_BRIDGE_BASE = 32'h80000000;
    localparam int APB_BRIDGE_WORDS = 32768;
    localparam logic [31:0] DMA_BASE = 32'h90001000;
    localparam int DMA_WORDS = 5;
    localparam logic [31:0] CLINT_BASE = 32'h90010000;
    localparam int CLINT_WORDS = 12288;
    localparam logic [31:0] PLIC_BASE = 32'hA0000000;
    localparam int PLIC_WORDS = 16777216;
    localparam logic [31:0] PRINTER_BASE = 32'hB0000000;
    localparam int PRINTER_WORDS = 1;

    // APB Regions
    localparam logic [31:0] GPIO0_BASE = 32'h80000000;
    localparam int GPIO0_WORDS = 18;
    localparam logic [31:0] GPIO1_BASE = 32'h80000100;
    localparam int GPIO1_WORDS = 18;
    localparam logic [31:0] GPIO2_BASE = 32'h80000200;
    localparam int GPIO2_WORDS = 18;
    localparam logic [31:0] GPIO3_BASE = 32'h80000300;
    localparam int GPIO3_WORDS = 18;
    localparam logic [31:0] PWM0_BASE = 32'h80001000;
    localparam int PWM0_WORDS = 67;
    localparam logic [31:0] TIMER0_BASE = 32'h80002000;
    localparam int TIMER0_WORDS = 8;
    localparam logic [31:0] SPI0_BASE = 32'h80004000;
    localparam int SPI0_WORDS = 8;
    localparam logic [31:0] I2C0_BASE = 32'h80005000;
    localparam int I2C0_WORDS = 6;
    localparam logic [31:0] UART_BASE = 32'h80006000;
    localparam int UART_WORDS = 9;
    localparam logic [31:0] IO_MUX_BASE = 32'h80007000;
    localparam int IO_MUX_WORDS = 2;
    localparam logic [31:0] GPIO_BOOT_BASE = 32'h80008000;
    localparam int GPIO_BOOT_WORDS = 18;

    // Interrupts
    localparam int IRQ_GPIO0 = 1;
    localparam int IRQ_GPIO1 = 2;
    localparam int IRQ_GPIO2 = 3;
    localparam int IRQ_GPIO3 = 4;
    localparam int IRQ_PWM0 = 5;
    localparam int IRQ_TIMER0 = 6;
    localparam int IRQ_SPI0 = 7;
    localparam int IRQ_I2C0 = 8;
    localparam int IRQ_UART = 9;
    localparam int IRQ_DMA = 10;
    localparam int IRQ_GPIO_BOOT = 11;

endpackage

`endif // AFT_MAP_PKG_SV
