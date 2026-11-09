#ifndef AFT_MAP_H
#define AFT_MAP_H

#include <stdint.h>

// Utility macros for memory-mapped I/O
#define REG32(addr) (*(volatile uint32_t *)(addr))

// AHB Regions
#define BOOT_ROM_BASE       0x00000400
#define ON_CHIP_RAM_BASE    0x00008400
#define OFF_CHIP_SRAM_BASE  0x00020000
#define APB_BRIDGE_BASE     0x80000000
#define DMA_BASE            0x90001000
#define CLINT_BASE          0x90010000
#define PLIC_BASE           0xA0000000
#define PRINTER_BASE        0xB0000000

// APB Regions
#define GPIO0_BASE          0x80000000
#define GPIO1_BASE          0x80000100
#define GPIO2_BASE          0x80000200
#define GPIO3_BASE          0x80000300
#define PWM0_BASE           0x80001000
#define TIMER0_BASE         0x80002000
#define SPI0_BASE           0x80004000
#define I2C0_BASE           0x80005000
#define UART_BASE           0x80006000
#define IO_MUX_BASE         0x80007000
#define GPIO_BOOT_BASE      0x80008000

// Interrupts
#define IRQ_GPIO0           1
#define IRQ_GPIO1           2
#define IRQ_GPIO2           3
#define IRQ_GPIO3           4
#define IRQ_PWM0            5
#define IRQ_TIMER0          6
#define IRQ_SPI0            7
#define IRQ_I2C0            8
#define IRQ_UART            9
#define IRQ_DMA             10
#define IRQ_GPIO_BOOT       11

// Test utility macros
#define TEST_PASS() do { REG32(PRINTER_BASE) = 1; return 0; } while(0)
#define TEST_FAIL() do { REG32(PRINTER_BASE) = 0xBAD; return 1; } while(0)
#define CHECK_EQ(actual, expected) do { if ((actual) != (expected)) TEST_FAIL(); } while(0)
#define CHECK_NEQ(actual, expected) do { if ((actual) == (expected)) TEST_FAIL(); } while(0)

#endif // AFT_MAP_H
