#include "../include/aft_map.h"

void test_gpio_block(uint32_t base, int width) {
    uint32_t mask = (width == 32) ? 0xFFFFFFFF : ((1U << width) - 1);
    
    // 1. Direction configuration and readback
    REG32(base + 0x08) = 0x0000FFFF & mask; // Lower 16 output, Upper 16 input
    CHECK_EQ(REG32(base + 0x08), 0x0000FFFF & mask);
    
    // 2. Data output tests (only on outputs)
    REG32(base + 0x04) = 0x0000A5A5 & mask;
    CHECK_EQ(REG32(base + 0x04) & mask, 0x0000A5A5 & mask);
    
    REG32(base + 0x04) = 0x00005A5A & mask;
    CHECK_EQ(REG32(base + 0x04) & mask, 0x00005A5A & mask);
    
    // 3. Walking 1s on output pins
    for (int i = 0; i < 16 && i < width; i++) {
        REG32(base + 0x04) = (1U << i);
        CHECK_EQ(REG32(base + 0x04) & mask, (1U << i));
    }
    
    // 4. Interrupt configuration (assume 0x18 is PULL_UP based on trace)
    // Actually, PULL_UP is 0x18.
    REG32(base + 0x18) = 0xFFFF0000 & mask;
    CHECK_EQ(REG32(base + 0x18), 0xFFFF0000 & mask);
    
    REG32(base + 0x24) = 0x00010000 & mask; // IRQ_RISE_EN
    CHECK_EQ(REG32(base + 0x24), 0x00010000 & mask);
}

int main() {
    test_gpio_block(GPIO0_BASE, 32);
    test_gpio_block(GPIO1_BASE, 16);
    test_gpio_block(GPIO2_BASE, 7);
    test_gpio_block(GPIO3_BASE, 1);
    
    TEST_PASS();
}
