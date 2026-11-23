#include "../include/aft_map.h"
int main() {
    uint32_t *src = (uint32_t *)ON_CHIP_RAM_BASE;
    uint32_t *dst = (uint32_t *)(ON_CHIP_RAM_BASE + 0x400);
    for(int i = 0; i < 32; i++) { src[i] = 0x12340000 | i; }
    REG32(DMA_BASE + 0x04) = (uint32_t)src; 
    CHECK_EQ(REG32(DMA_BASE + 0x04), (uint32_t)src);
    REG32(DMA_BASE + 0x08) = (uint32_t)dst;
    CHECK_EQ(REG32(DMA_BASE + 0x08), (uint32_t)dst);
    REG32(DMA_BASE + 0x0C) = 32; 
    CHECK_EQ(REG32(DMA_BASE + 0x0C), 32);
    REG32(DMA_BASE + 0x10) = 0x1881; // en=1, psize=2 (word), inc_dest=1, inc_src=1
    int timeout = 50000;
    while ((REG32(DMA_BASE + 0x14) & 1) == 0 && timeout > 0) { timeout--; }
    CHECK_NEQ(timeout, 0);
    for(int i = 0; i < 32; i++) { CHECK_EQ(dst[i], src[i]); }
    TEST_PASS();
}
