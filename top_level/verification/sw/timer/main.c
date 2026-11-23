#include "../include/aft_map.h"
int main() {
    REG32(TIMER0_BASE + 0x00) = 0; 
    REG32(TIMER0_BASE + 0x04) = 0; 
    REG32(TIMER0_BASE + 0x08) = 0x100; 
    REG32(TIMER0_BASE + 0x00) = 1; 
    uint32_t cnt1 = REG32(TIMER0_BASE + 0x04);
    for(volatile int i=0; i<50; i++);
    uint32_t cnt2 = REG32(TIMER0_BASE + 0x04);
    
    if (cnt1 == cnt2) {
        REG32(PRINTER_BASE) = cnt1;
        REG32(PRINTER_BASE) = cnt2;
        REG32(PRINTER_BASE) = __LINE__;
        TEST_FAIL();
    }
    int timeout = 10000;
    while ((REG32(TIMER0_BASE + 0x14) & 1) == 0 && timeout > 0) { timeout--; }
    
    if (timeout == 0) {
        REG32(PRINTER_BASE) = REG32(TIMER0_BASE + 0x14);
        REG32(PRINTER_BASE) = timeout;
        REG32(PRINTER_BASE) = __LINE__;
        TEST_FAIL();
    }
    
    REG32(TIMER0_BASE + 0x14) = 1; 
    TEST_PASS();
}
