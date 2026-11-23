#include "../include/aft_map.h"

int main() {
    // 1. CLINT (Core-Local Interruptor) checks
    // Machine Software Interrupt Pending R/W (hart 0)
    REG32(CLINT_BASE + 0x00) = 1; 
    CHECK_EQ(REG32(CLINT_BASE + 0x00), 1);
    REG32(CLINT_BASE + 0x00) = 0; 
    CHECK_EQ(REG32(CLINT_BASE + 0x00), 0);
    
    // Machine Timer Compare (mtimecmp)
    REG32(CLINT_BASE + 0x4000) = 0xDEADBEEF; // Lower 32 bits
    REG32(CLINT_BASE + 0x4004) = 0xCAFEBABE; // Upper 32 bits
    CHECK_EQ(REG32(CLINT_BASE + 0x4000), 0xDEADBEEF);
    CHECK_EQ(REG32(CLINT_BASE + 0x4004), 0xCAFEBABE);
    
    // 2. PLIC (Platform-Level Interrupt Controller) checks
    // Priority Registers R/W (test multiple IRQs)
    REG32(PLIC_BASE + 4 * IRQ_UART) = 7;
    CHECK_EQ(REG32(PLIC_BASE + 4 * IRQ_UART), 7);
    
    REG32(PLIC_BASE + 4 * IRQ_DMA) = 3;
    CHECK_EQ(REG32(PLIC_BASE + 4 * IRQ_DMA), 3);

    REG32(PLIC_BASE + 4 * IRQ_TIMER0) = 5;
    CHECK_EQ(REG32(PLIC_BASE + 4 * IRQ_TIMER0), 5);
    
    // Interrupt Enable Registers (Assuming hart 0 M-mode)
    uint32_t enables = (1 << IRQ_UART) | (1 << IRQ_DMA) | (1 << IRQ_TIMER0);
    REG32(PLIC_BASE + 0x2000) = enables;
    CHECK_EQ(REG32(PLIC_BASE + 0x2000), enables);
    
    // Threshold Register
    REG32(PLIC_BASE + 0x200000) = 4; // Threshold = 4 (blocks IRQ_DMA=3)
    CHECK_EQ(REG32(PLIC_BASE + 0x200000), 4);

    // Disable all again
    REG32(PLIC_BASE + 0x2000) = 0;
    CHECK_EQ(REG32(PLIC_BASE + 0x2000), 0);
    
    TEST_PASS();
}
