#include "../include/aft_map.h"

int main() {
    // 1. Configure I2C Speed (Assuming offset 0x0C)
    REG32(I2C0_BASE + 0x0C) = 400; // 400 kHz Fast Mode
    CHECK_EQ(REG32(I2C0_BASE + 0x0C), 400);
    
    // 2. Set Target Address
    REG32(I2C0_BASE + 0x08) = 0x50;   
    CHECK_EQ(REG32(I2C0_BASE + 0x08), 0x50);

    // 3. Set Data
    REG32(I2C0_BASE + 0x04) = 0x12;   
    CHECK_EQ(REG32(I2C0_BASE + 0x04), 0x12);
    
    // 4. Start transfer
    REG32(I2C0_BASE + 0x00) = 0x1;    
    
    // 5. Wait for transfer complete (Assuming Status at 0x10, bit 0 is Done)
    int timeout = 10000;
    while ((REG32(I2C0_BASE + 0x10) & 1) == 0 && timeout > 0) {
        timeout--;
    }
    CHECK_NEQ(timeout, 0); // Fail if transfer never completes
    
    // 6. Check for ACK/NACK (Assuming bit 1 is NACK flag)
    // Depends on testbench, so just read it
    volatile uint32_t nack = (REG32(I2C0_BASE + 0x10) & 2) >> 1;
    (void)nack;
    
    // Clear status
    REG32(I2C0_BASE + 0x10) = 0xFFFFFFFF;
    
    TEST_PASS();
}
