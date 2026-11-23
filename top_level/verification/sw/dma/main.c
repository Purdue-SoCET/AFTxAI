#include "../include/aft_map.h"

int main() {
    uint32_t *src_word = (uint32_t *)ON_CHIP_RAM_BASE;
    uint32_t *dst_word = (uint32_t *)(ON_CHIP_RAM_BASE + 0x400);
    uint16_t *src_half = (uint16_t *)(ON_CHIP_RAM_BASE + 0x800);
    uint16_t *dst_half = (uint16_t *)(ON_CHIP_RAM_BASE + 0xC00);
    uint8_t *src_byte = (uint8_t *)(ON_CHIP_RAM_BASE + 0x1000);
    uint8_t *dst_byte = (uint8_t *)(ON_CHIP_RAM_BASE + 0x1400);

    // 1. Word Transfer (PSIZE=2)
    for(int i = 0; i < 32; i++) { src_word[i] = 0x12340000 | i; dst_word[i] = 0; }
    REG32(DMA_BASE + 0x04) = (uint32_t)src_word; 
    REG32(DMA_BASE + 0x08) = (uint32_t)dst_word;
    REG32(DMA_BASE + 0x0C) = 32; 
    // EN=1, PSIZE=2 (word), INC_DEST=1, INC_SRC=1. -> 1 | (2<<6) | (1<<11) | (1<<12) = 1 | 128 | 2048 | 4096 = 0x1881
    REG32(DMA_BASE + 0x10) = 0x1881; 
    
    int timeout = 50000;
    while ((REG32(DMA_BASE + 0x14) & 1) == 0 && timeout > 0) { timeout--; }
    CHECK_NEQ(timeout, 0);
    // Clear SR
    volatile uint32_t sr = REG32(DMA_BASE + 0x14);

    for(int i = 0; i < 32; i++) { CHECK_EQ(dst_word[i], src_word[i]); }

    // 2. Half-Word Transfer (PSIZE=1)
    for(int i = 0; i < 16; i++) { src_half[i] = 0xA5A0 | i; dst_half[i] = 0; }
    REG32(DMA_BASE + 0x04) = (uint32_t)src_half; 
    REG32(DMA_BASE + 0x08) = (uint32_t)dst_half;
    REG32(DMA_BASE + 0x0C) = 16; 
    // EN=1, PSIZE=1, INC_DEST=1, INC_SRC=1. -> 1 | (1<<6) | 2048 | 4096 = 0x1841
    REG32(DMA_BASE + 0x10) = 0x1841; 
    
    timeout = 50000;
    while ((REG32(DMA_BASE + 0x14) & 1) == 0 && timeout > 0) { timeout--; }
    CHECK_NEQ(timeout, 0);
    sr = REG32(DMA_BASE + 0x14); // clear

    for(int i = 0; i < 16; i++) { CHECK_EQ(dst_half[i], src_half[i]); }

    // 3. Byte Transfer (PSIZE=0)
    for(int i = 0; i < 8; i++) { src_byte[i] = 0x55 + i; dst_byte[i] = 0; }
    REG32(DMA_BASE + 0x04) = (uint32_t)src_byte; 
    REG32(DMA_BASE + 0x08) = (uint32_t)dst_byte;
    REG32(DMA_BASE + 0x0C) = 8; 
    // EN=1, PSIZE=0, INC_DEST=1, INC_SRC=1. -> 1 | (0<<6) | 2048 | 4096 = 0x1801
    REG32(DMA_BASE + 0x10) = 0x1801; 
    
    timeout = 50000;
    while ((REG32(DMA_BASE + 0x14) & 1) == 0 && timeout > 0) { timeout--; }
    CHECK_NEQ(timeout, 0);
    sr = REG32(DMA_BASE + 0x14); // clear

    for(int i = 0; i < 8; i++) { CHECK_EQ(dst_byte[i], src_byte[i]); }

    TEST_PASS();
}
