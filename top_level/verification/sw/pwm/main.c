#include "../include/aft_map.h"

int main() {
    // 1. Initial configuration
    REG32(PWM0_BASE + 0x04) = 1000; // Period
    CHECK_EQ(REG32(PWM0_BASE + 0x04), 1000);

    REG32(PWM0_BASE + 0x08) = 250;  // Duty Cycle (25%)
    CHECK_EQ(REG32(PWM0_BASE + 0x08), 250);
    
    // 2. Polarity control (Assume offset 0x0C)
    REG32(PWM0_BASE + 0x0C) = 1; // Inverted
    CHECK_EQ(REG32(PWM0_BASE + 0x0C), 1);
    
    // 3. Enable PWM
    REG32(PWM0_BASE + 0x00) = 0x1;    
    CHECK_EQ(REG32(PWM0_BASE + 0x00), 0x1);
    
    // 4. On-the-fly update check
    REG32(PWM0_BASE + 0x08) = 500;  // Duty Cycle (50%)
    CHECK_EQ(REG32(PWM0_BASE + 0x08), 500);
    
    TEST_PASS();
}
