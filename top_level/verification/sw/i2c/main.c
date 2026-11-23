#include "../include/aft_map.h"
int main() {
    REG32(I2C0_BASE + 0x04) = 400; 
    CHECK_EQ(REG32(I2C0_BASE + 0x04), 400);
    REG32(I2C0_BASE + 0x00) = 1; 
    REG32(I2C0_BASE + 0x08) = 0x50; 
    REG32(I2C0_BASE + 0x10) = 0x1; 
    int timeout = 10000;
    while ((REG32(I2C0_BASE + 0x14) & 8) == 0 && timeout > 0) { timeout--; }
    CHECK_NEQ(timeout, 0);
    REG32(I2C0_BASE + 0x10) = 0x8; 
    TEST_PASS();
}
