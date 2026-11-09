#include "../include/aft_map.h"

int main() {
    // 1. Data Pattern Test over off-chip SRAM
    uint32_t *sram = (uint32_t *)OFF_CHIP_SRAM_BASE;
    int test_words = 4096; // Test 16KB of SRAM boundary
    
    // Write patterns: Address XOR'd
    for(int i = 0; i < test_words; i++) {
        sram[i] = (uint32_t)&sram[i] ^ 0xAAAAAAAA;
    }
    
    // Verify Address XOR'd
    for(int i = 0; i < test_words; i++) {
        CHECK_EQ(sram[i], (uint32_t)&sram[i] ^ 0xAAAAAAAA);
    }

    // 2. Walking 1s Test on a single word to verify data lines
    for (int i = 0; i < 32; i++) {
        sram[100] = (1U << i);
        CHECK_EQ(sram[100], (1U << i));
    }

    // 3. Walking 0s Test
    for (int i = 0; i < 32; i++) {
        sram[100] = ~(1U << i);
        CHECK_EQ(sram[100], ~(1U << i));
    }
    
    TEST_PASS();
}
