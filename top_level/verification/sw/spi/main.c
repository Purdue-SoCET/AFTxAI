#include "../include/aft_map.h"

int main() {
    // 1. Configure Clock Divider
    REG32(SPI0_BASE + 0x08) = 10;
    CHECK_EQ(REG32(SPI0_BASE + 0x08), 10);
    
    // 2. Configure CTRL (Enable SPI, maybe polarity/phase depending on bit 1)
    REG32(SPI0_BASE + 0x00) = 0x3; // EN=1 and another config bit
    CHECK_EQ(REG32(SPI0_BASE + 0x00), 0x3);
    
    // 3. Transmit a sequence of bytes
    uint8_t tx_data[] = {0xAA, 0x55, 0x00, 0xFF, 0x12, 0x34};
    for(int i = 0; i < 6; i++) {
        REG32(SPI0_BASE + 0x0C) = tx_data[i];
        
        // Wait for transfer completion (assume bit 0 is busy or TX empty)
        // Wait for bit 0 of STATUS to be 1 (DONE or TX Empty)
        int timeout = 10000;
        while ((REG32(SPI0_BASE + 0x04) & 1) == 0 && timeout > 0) { timeout--; }
        CHECK_NEQ(timeout, 0);

        // Optionally read RX Data (even if dummy) to clear RX FIFO and test read path
        uint32_t rx_val = REG32(SPI0_BASE + 0x10);
        // We can't guarantee what rx_val is without a known SPI slave, 
        // but this verifies the address is readable without error.
    }

    // 4. Disable SPI
    REG32(SPI0_BASE + 0x00) = 0x0; 
    CHECK_EQ(REG32(SPI0_BASE + 0x00), 0x0);

    TEST_PASS();
}
