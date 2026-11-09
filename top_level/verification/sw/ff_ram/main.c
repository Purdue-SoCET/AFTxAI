#include "../include/aft_map.h"

int main() {
    // 1. Data Pattern Test over address ranges
    uint32_t *ram = (uint32_t *)ON_CHIP_RAM_BASE;
    int test_words = 1024; // Test 4KB
    
    // Write patterns: Address-in-Data
    for(int i = 0; i < test_words; i++) {
        ram[i] = (uint32_t)&ram[i];
    }
    
    // Verify Address-in-Data
    for(int i = 0; i < test_words; i++) {
        CHECK_EQ(ram[i], (uint32_t)&ram[i]);
    }

    // 2. Walking 1s Test on a single word to verify data lines
    for (int i = 0; i < 32; i++) {
        ram[0] = (1U << i);
        CHECK_EQ(ram[0], (1U << i));
    }

    // 3. Walking 0s Test
    for (int i = 0; i < 32; i++) {
        ram[0] = ~(1U << i);
        CHECK_EQ(ram[0], ~(1U << i));
    }
    
    TEST_PASS();
}
