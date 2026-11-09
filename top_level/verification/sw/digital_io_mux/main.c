#include "../include/aft_map.h"

int main() {
    // Check pin multiplexing mapping for multiple pins
    // Assume offset 0x00 handles pin 0, 0x04 handles pin 1, etc.
    // Functions: 0 = GPIO, 1 = UART, 2 = SPI, 3 = I2C
    
    for(int pin = 0; pin < 8; pin++) {
        uint32_t func = pin % 4;
        REG32(IO_MUX_BASE + (pin * 4)) = func; 
        CHECK_EQ(REG32(IO_MUX_BASE + (pin * 4)), func);
    }
    
    // Test a global override bit if one exists (Assume offset 0x100)
    REG32(IO_MUX_BASE + 0x100) = 1;
    CHECK_EQ(REG32(IO_MUX_BASE + 0x100), 1);
    
    TEST_PASS();
}
