#include "../include/aft_map.h"

int main() {
    uint32_t *ram = (uint32_t *)ON_CHIP_RAM_BASE;
    int test_words = 1024; // Test 4KB (1024 words)
    
    // 1. Alternating Bit Pattern Test (0x55555555 / 0xAAAAAAAA)
    for(int i = 0; i < test_words; i++) {
        ram[i] = (i % 2 == 0) ? 0x55555555 : 0xAAAAAAAA;
    }
    for(int i = 0; i < test_words; i++) {
        uint32_t expected = (i % 2 == 0) ? 0x55555555 : 0xAAAAAAAA;
        CHECK_EQ(ram[i], expected);
    }
    
    // 2. Inverse Alternating Bit Pattern Test
    for(int i = 0; i < test_words; i++) {
        ram[i] = (i % 2 == 0) ? 0xAAAAAAAA : 0x55555555;
    }
    for(int i = 0; i < test_words; i++) {
        uint32_t expected = (i % 2 == 0) ? 0xAAAAAAAA : 0x55555555;
        CHECK_EQ(ram[i], expected);
    }

    // 3. Address-in-Data Test
    for(int i = 0; i < test_words; i++) {
        ram[i] = (uint32_t)&ram[i];
    }
    for(int i = 0; i < test_words; i++) {
        CHECK_EQ(ram[i], (uint32_t)&ram[i]);
    }

    // 4. Walking 1s Test on multiple words
    for(int w = 0; w < 4; w++) { // test first 4 words
        for (int i = 0; i < 32; i++) {
            ram[w] = (1U << i);
            CHECK_EQ(ram[w], (1U << i));
        }
    }

    // 5. Walking 0s Test on multiple words
    for(int w = 0; w < 4; w++) { // test first 4 words
        for (int i = 0; i < 32; i++) {
            ram[w] = ~(1U << i);
            CHECK_EQ(ram[w], ~(1U << i));
        }
    }
    
    TEST_PASS();
}
