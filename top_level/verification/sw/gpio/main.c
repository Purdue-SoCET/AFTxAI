#include "../include/aft_map.h"

int main() {
    // 1. Split IO direction: Lower 16 bits = Output, Upper 16 bits = Input
    REG32(GPIO0_BASE + 0x00) = 0x0000FFFF;
    CHECK_EQ(REG32(GPIO0_BASE + 0x00), 0x0000FFFF);
    
    // 2. Drive patterns on outputs
    REG32(GPIO0_BASE + 0x04) = 0x0000A5A5;
    CHECK_EQ(REG32(GPIO0_BASE + 0x04), 0x0000A5A5);
    
    REG32(GPIO0_BASE + 0x04) = 0x00005A5A;
    CHECK_EQ(REG32(GPIO0_BASE + 0x04), 0x00005A5A);

    // 3. Configure pull-ups/pull-downs (Assuming offset 0x0C)
    REG32(GPIO0_BASE + 0x0C) = 0xFFFF0000; // Pull-up on inputs
    CHECK_EQ(REG32(GPIO0_BASE + 0x0C), 0xFFFF0000);
    
    // 4. Configure interrupts (Assuming offset 0x10 is Int Enable)
    REG32(GPIO0_BASE + 0x10) = 0x00010000; // Enable interrupt on bit 16
    CHECK_EQ(REG32(GPIO0_BASE + 0x10), 0x00010000);

    TEST_PASS();
}
