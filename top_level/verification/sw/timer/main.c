#include "../include/aft_map.h"

int main() {
    // 1. Configure Timer
    REG32(TIMER0_BASE + 0x04) = 0x100; // Load value
    CHECK_EQ(REG32(TIMER0_BASE + 0x04), 0x100);

    // 2. Start Timer (Bit 0 = Enable)
    REG32(TIMER0_BASE + 0x00) = 0x1;    
    CHECK_EQ(REG32(TIMER0_BASE + 0x00), 0x1);
    
    // 3. Ensure counter is actually ticking
    // Assuming offset 0x08 holds current counter value
    uint32_t cnt1 = REG32(TIMER0_BASE + 0x08);
    for(volatile int i=0; i<50; i++); // Wait
    uint32_t cnt2 = REG32(TIMER0_BASE + 0x08);
    CHECK_NEQ(cnt1, cnt2); // Counter should have changed
    
    // 4. Wait for expiration status (Assuming Bit 0 at offset 0x0C is 'Expired')
    int timeout = 10000;
    while ((REG32(TIMER0_BASE + 0x0C) & 1) == 0 && timeout > 0) {
        timeout--;
    }
    CHECK_NEQ(timeout, 0); // Fail if timer never expires
    
    // 5. Clear expiration status (Assume write 1 to clear)
    REG32(TIMER0_BASE + 0x0C) = 1;
    CHECK_EQ(REG32(TIMER0_BASE + 0x0C) & 1, 0); // Verify cleared
    
    TEST_PASS();
}
