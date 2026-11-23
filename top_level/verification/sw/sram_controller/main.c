#include "../include/aft_map.h"

int main() {
    uint32_t *sram = (uint32_t *)OFF_CHIP_SRAM_BASE;
    int test_words = 1024; // Test 4KB
    
    // 1. Address-in-Data XORed pattern
    for(int i = 0; i < test_words; i++) {
        sram[i] = (uint32_t)&sram[i] ^ 0xAAAAAAAA;
    }
    for(int i = 0; i < test_words; i++) {
        CHECK_EQ(sram[i], (uint32_t)&sram[i] ^ 0xAAAAAAAA);
    }

    // 2. Checkerboard pattern
    for(int i = 0; i < test_words; i++) {
        sram[i] = (i % 2 == 0) ? 0x55555555 : 0xAAAAAAAA;
    }
    for(int i = 0; i < test_words; i++) {
        uint32_t expected = (i % 2 == 0) ? 0x55555555 : 0xAAAAAAAA;
        CHECK_EQ(sram[i], expected);
    }

    // 3. Inverse Checkerboard pattern
    for(int i = 0; i < test_words; i++) {
        sram[i] = (i % 2 == 0) ? 0xAAAAAAAA : 0x55555555;
    }
    for(int i = 0; i < test_words; i++) {
        uint32_t expected = (i % 2 == 0) ? 0xAAAAAAAA : 0x55555555;
        CHECK_EQ(sram[i], expected);
    }

    // 4. Walking 1s Test on a subset of words
    for (int w = 0; w < 4; w++) {
        for (int i = 0; i < 32; i++) { 
            sram[100 + w] = (1U << i); 
            CHECK_EQ(sram[100 + w], (1U << i)); 
        }
    }

    // 5. Walking 0s Test on a subset of words
    for (int w = 0; w < 4; w++) {
        for (int i = 0; i < 32; i++) { 
            sram[100 + w] = ~(1U << i); 
            CHECK_EQ(sram[100 + w], ~(1U << i)); 
        }
    }
    
    // 6. Byte-level access test (Write 8-bit, Read 32-bit)
    uint8_t *sram_bytes = (uint8_t *)OFF_CHIP_SRAM_BASE;
    sram[0] = 0; // Clear first word
    sram_bytes[0] = 0x11;
    sram_bytes[1] = 0x22;
    sram_bytes[2] = 0x33;
    sram_bytes[3] = 0x44;
    // Expected word value depends on endianness. RISC-V is little-endian.
    CHECK_EQ(sram[0], 0x44332211);
    
    TEST_PASS();
}
