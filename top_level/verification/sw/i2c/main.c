#include "../include/aft_map.h"

void wait_i2c_done() {
    int timeout = 50000;
    // Wait for DONE bit (bit 3)
    while ((REG32(I2C0_BASE + 0x14) & 8) == 0 && timeout > 0) { timeout--; }
    CHECK_NEQ(timeout, 0);
    // Clear DONE bit (W1C on bit 3)
    REG32(I2C0_BASE + 0x14) = 8;
}

int main() {
    // 1. Initial Configure
    REG32(I2C0_BASE + 0x04) = 400; // PRESCALE
    CHECK_EQ(REG32(I2C0_BASE + 0x04), 400);

    REG32(I2C0_BASE + 0x00) = 1; // EN=1, IRQ_EN=0
    CHECK_EQ(REG32(I2C0_BASE + 0x00), 1);
    
    // 2. Transmit Device Address (Write operation)
    REG32(I2C0_BASE + 0x08) = 0xA0; // TXDATA: Device 0x50 << 1 + Write (0)
    // CMD: START (1) | WRITE (4) = 5
    REG32(I2C0_BASE + 0x10) = 0x5; 
    wait_i2c_done();
    
    // 3. Transmit Register Address
    REG32(I2C0_BASE + 0x08) = 0x00; // TXDATA: Reg 0
    // CMD: WRITE (4)
    REG32(I2C0_BASE + 0x10) = 0x4; 
    wait_i2c_done();

    // 4. Repeated START for Read
    REG32(I2C0_BASE + 0x08) = 0xA1; // TXDATA: Device 0x50 << 1 + Read (1)
    // CMD: START (1) | WRITE (4) = 5
    REG32(I2C0_BASE + 0x10) = 0x5; 
    wait_i2c_done();

    // 5. Read Byte 1 (ACK)
    // CMD: READ (8)
    REG32(I2C0_BASE + 0x10) = 0x8; 
    wait_i2c_done();
    uint32_t val1 = REG32(I2C0_BASE + 0x0C);

    // 6. Read Byte 2 (NACK + STOP)
    // CMD: READ (8) | STOP (2) | NACK (16) = 26 (0x1A)
    REG32(I2C0_BASE + 0x10) = 0x1A; 
    wait_i2c_done();
    uint32_t val2 = REG32(I2C0_BASE + 0x0C);

    // Turn off I2C
    REG32(I2C0_BASE + 0x00) = 0; 
    
    TEST_PASS();
}
