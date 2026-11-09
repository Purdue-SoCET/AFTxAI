#include "../include/aft_map.h"

int main() {
    // 1. Set up Memory
    uint32_t *src = (uint32_t *)ON_CHIP_RAM_BASE;
    uint32_t *dst = (uint32_t *)OFF_CHIP_SRAM_BASE;
    
    // Initialize Source and clear Destination
    for(int i = 0; i < 32; i++) {
        src[i] = 0x12340000 | i;
        dst[i] = 0;
    }

    // 2. Configure DMA Channels
    REG32(DMA_BASE + 0x00) = (uint32_t)src; 
    CHECK_EQ(REG32(DMA_BASE + 0x00), (uint32_t)src);

    REG32(DMA_BASE + 0x04) = (uint32_t)dst;
    CHECK_EQ(REG32(DMA_BASE + 0x04), (uint32_t)dst);

    REG32(DMA_BASE + 0x08) = 32 * 4; // Length in bytes (128 bytes)
    CHECK_EQ(REG32(DMA_BASE + 0x08), 128);
    
    // 3. Start DMA transfer (Bit 0 = Enable)
    REG32(DMA_BASE + 0x0C) = 0x1;     
    
    // 4. Poll for completion (Assuming offset 0x10 Bit 0 is 'Done')
    int timeout = 50000;
    while ((REG32(DMA_BASE + 0x10) & 1) == 0 && timeout > 0) {
        timeout--;
    }
    CHECK_NEQ(timeout, 0); // DMA did not complete in time
    
    // Clear Done flag
    REG32(DMA_BASE + 0x10) = 1;
    
    // 5. Verify transferred data
    for(int i = 0; i < 32; i++) {
        CHECK_EQ(dst[i], src[i]);
    }
    
    TEST_PASS();
}
