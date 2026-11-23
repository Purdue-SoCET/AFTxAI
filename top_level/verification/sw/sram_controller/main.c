#include "../include/aft_map.h"
int main() {
    uint32_t *sram = (uint32_t *)OFF_CHIP_SRAM_BASE;
    int test_words = 256; 
    for(int i = 0; i < test_words; i++) sram[i] = (uint32_t)&sram[i] ^ 0xAAAAAAAA;
    for(int i = 0; i < test_words; i++) CHECK_EQ(sram[i], (uint32_t)&sram[i] ^ 0xAAAAAAAA);
    for (int i = 0; i < 32; i++) { sram[100] = (1U << i); CHECK_EQ(sram[100], (1U << i)); }
    for (int i = 0; i < 32; i++) { sram[100] = ~(1U << i); CHECK_EQ(sram[100], ~(1U << i)); }
    TEST_PASS();
}
