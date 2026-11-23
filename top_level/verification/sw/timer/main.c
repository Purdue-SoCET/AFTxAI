#include "../include/aft_map.h"

int main() {
    // 1. Initial State Checks
    CHECK_EQ(REG32(TIMER0_BASE + 0x1C), 0x544D0101); // TIMER_INFO
    
    // 2. Configure Timer (Periodic mode)
    REG32(TIMER0_BASE + 0x00) = 0; // Disable
    REG32(TIMER0_BASE + 0x04) = 0; // COUNT
    REG32(TIMER0_BASE + 0x08) = 0x100; // PERIOD
    REG32(TIMER0_BASE + 0x0C) = 0x3; // PRESCALE = 3 (divide by 4)
    REG32(TIMER0_BASE + 0x10) = 0x1; // IRQ_ENABLE (bit 0 = timer event)
    
    // Enable timer (EN=1)
    REG32(TIMER0_BASE + 0x00) = 1; 
    
    // 3. Counting check
    uint32_t cnt1 = REG32(TIMER0_BASE + 0x04);
    for(volatile int i=0; i<50; i++);
    uint32_t cnt2 = REG32(TIMER0_BASE + 0x04);
    
    if (cnt1 >= cnt2) {
        REG32(PRINTER_BASE) = cnt1;
        REG32(PRINTER_BASE) = cnt2;
        TEST_FAIL();
    }
    
    // 4. Wait for Timer IRQ/Event
    int timeout = 10000;
    // Wait for IRQ_PENDING bit 0
    while ((REG32(TIMER0_BASE + 0x14) & 1) == 0 && timeout > 0) { timeout--; }
    
    if (timeout == 0) {
        REG32(PRINTER_BASE) = REG32(TIMER0_BASE + 0x14);
        TEST_FAIL();
    }
    
    // Clear pending IRQ
    REG32(TIMER0_BASE + 0x14) = 1; 

    // 5. One-Shot Mode (if EN=1, MODE=1 is one-shot, but we will just write 0 to stop)
    REG32(TIMER0_BASE + 0x00) = 0; 
    REG32(TIMER0_BASE + 0x04) = 0; 

    TEST_PASS();
}
