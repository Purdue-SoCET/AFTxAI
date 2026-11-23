#include "../include/aft_map.h"

int main() {
    // 1. Initial configuration (Normal 25% Duty)
    REG32(PWM0_BASE + 0x04) = 1000; // Period
    CHECK_EQ(REG32(PWM0_BASE + 0x04), 1000);

    REG32(PWM0_BASE + 0x08) = 250;  // Duty Cycle (25%)
    CHECK_EQ(REG32(PWM0_BASE + 0x08), 250);
    
    REG32(PWM0_BASE + 0x0C) = 1; // Prescale = 1 (divide by 2)
    CHECK_EQ(REG32(PWM0_BASE + 0x0C), 1);
    
    // Trigger update to shadow registers
    REG32(PWM0_BASE + 0x10) = 0x1;
    
    // Enable PWM, Polarity Normal
    REG32(PWM0_BASE + 0x00) = 0x1; // EN=1, POLARITY=0
    CHECK_EQ(REG32(PWM0_BASE + 0x00), 0x1);
    
    // 2. On-the-fly update to 50% Duty Cycle
    REG32(PWM0_BASE + 0x08) = 500;  
    CHECK_EQ(REG32(PWM0_BASE + 0x08), 500);
    REG32(PWM0_BASE + 0x10) = 0x1; // Trigger update
    while(REG32(PWM0_BASE + 0x14) & 1); // Wait for update
    
    // 3. Update to 0% Duty Cycle
    REG32(PWM0_BASE + 0x08) = 0;  
    CHECK_EQ(REG32(PWM0_BASE + 0x08), 0);
    REG32(PWM0_BASE + 0x10) = 0x1; // Trigger update
    while(REG32(PWM0_BASE + 0x14) & 1); // Wait for update
    
    // 4. Update to 100% Duty Cycle (Duty >= Period)
    REG32(PWM0_BASE + 0x08) = 1000;  
    CHECK_EQ(REG32(PWM0_BASE + 0x08), 1000);
    REG32(PWM0_BASE + 0x10) = 0x1; // Trigger update
    while(REG32(PWM0_BASE + 0x14) & 1); // Wait for update

    // 5. Change Polarity (Inverted)
    REG32(PWM0_BASE + 0x00) = 0x3; // EN=1, POLARITY=1
    CHECK_EQ(REG32(PWM0_BASE + 0x00), 0x3);

    // Disable
    REG32(PWM0_BASE + 0x00) = 0x0; 

    TEST_PASS();
}
