#include "../include/aft_map.h"
int main() {
    REG32(SPI0_BASE + 0x08) = 10;
    CHECK_EQ(REG32(SPI0_BASE + 0x08), 10);
    REG32(SPI0_BASE + 0x00) = 0x3;
    CHECK_EQ(REG32(SPI0_BASE + 0x00), 0x3);
    REG32(SPI0_BASE + 0x0C) = 0xAA;
    int timeout = 10000;
    while ((REG32(SPI0_BASE + 0x04) & 1) == 0 && timeout > 0) { timeout--; }
    CHECK_NEQ(timeout, 0);
    TEST_PASS();
}
