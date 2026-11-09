#include "../include/aft_map.h"

int main() {
    // 1. CLINT (Core-Local Interruptor) checks
    // Machine Software Interrupt Pending R/W
    REG32(CLINT_BASE + 0x00) = 1; 
    CHECK_EQ(REG32(CLINT_BASE + 0x00), 1);
    REG32(CLINT_BASE + 0x00) = 0; 
    CHECK_EQ(REG32(CLINT_BASE + 0x00), 0);
    
    // Machine Timer Compare (mtimecmp)
    REG32(CLINT_BASE + 0x4000) = 0xFFFFFFFF; // Lower 32 bits
    CHECK_EQ(REG32(CLINT_BASE + 0x4000), 0xFFFFFFFF);
    
    // 2. PLIC (Platform-Level Interrupt Controller) checks
    // Priority Registers R/W
    REG32(PLIC_BASE + 4 * IRQ_UART) = 7;
    CHECK_EQ(REG32(PLIC_BASE + 4 * IRQ_UART), 7);
    
    // Interrupt Enable Registers (Assuming hart 0 M-mode)
    REG32(PLIC_BASE + 0x2000) = (1 << IRQ_UART) | (1 << IRQ_DMA);
    CHECK_EQ(REG32(PLIC_BASE + 0x2000), (1 << IRQ_UART) | (1 << IRQ_DMA));
    
    // Threshold Register
    REG32(PLIC_BASE + 0x200000) = 1;
    CHECK_EQ(REG32(PLIC_BASE + 0x200000), 1);
    
    TEST_PASS();
}
