#include "../include/aft_map.h"

int main() {
    // 1. Configure SPI Controller
    REG32(SPI0_BASE + 0x08) = 10;     // Clock divider
    CHECK_EQ(REG32(SPI0_BASE + 0x08), 10);
    
    REG32(SPI0_BASE + 0x00) = 0x3;    // Enable + Master
    CHECK_EQ(REG32(SPI0_BASE + 0x00), 0x3);
    
    // 2. Chip Select Control (Assuming offset 0x10)
    REG32(SPI0_BASE + 0x10) = 0x1;    // Assert CS0
    CHECK_EQ(REG32(SPI0_BASE + 0x10), 0x1);
    
    // 3. Send Data Byte
    REG32(SPI0_BASE + 0x04) = 0xAA;   
    
    // 4. Wait for transmission complete (Assuming Status at 0x0C, bit 0 is TX Empty)
    int timeout = 10000;
    while ((REG32(SPI0_BASE + 0x0C) & 1) == 0 && timeout > 0) {
        timeout--;
    }
    CHECK_NEQ(timeout, 0); // Fail if never transmits
    
    // 5. Read RX Data (Assuming offset 0x14)
    volatile uint32_t rx_data = REG32(SPI0_BASE + 0x14);
    // Cannot strongly assert RX value without a real loopback in TB, just perform read
    (void)rx_data; 
    
    // De-assert CS
    REG32(SPI0_BASE + 0x10) = 0x0; 
    
    TEST_PASS();
}
