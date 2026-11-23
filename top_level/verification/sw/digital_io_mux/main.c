#include "../include/aft_map.h"

int main() {
    // 1. Basic configuration test: 32 pins, multiple functions
    for(int pin = 0; pin < 32; pin++) {
        uint32_t func = pin % 4; // Functions 0-3
        uint32_t reg_offset = (pin * 2) / 32 * 4;
        uint32_t bit_offset = (pin * 2) % 32;
        
        uint32_t val = REG32(IO_MUX_BASE + reg_offset);
        val = (val & ~(3 << bit_offset)) | (func << bit_offset);
        REG32(IO_MUX_BASE + reg_offset) = val; 
        
        uint32_t read_val = (REG32(IO_MUX_BASE + reg_offset) >> bit_offset) & 3;
        CHECK_EQ(read_val, func);
    }
    
    // 2. Clear all pins to function 0 and verify
    REG32(IO_MUX_BASE + 0x00) = 0x00000000;
    REG32(IO_MUX_BASE + 0x04) = 0x00000000;
    CHECK_EQ(REG32(IO_MUX_BASE + 0x00), 0);
    CHECK_EQ(REG32(IO_MUX_BASE + 0x04), 0);
    
    // 3. Set a checkerboard pattern and verify no aliasing
    REG32(IO_MUX_BASE + 0x00) = 0x55555555; // Func 1 for pins 0-15
    REG32(IO_MUX_BASE + 0x04) = 0xAAAAAAAA; // Func 2 for pins 16-31
    CHECK_EQ(REG32(IO_MUX_BASE + 0x00), 0x55555555);
    CHECK_EQ(REG32(IO_MUX_BASE + 0x04), 0xAAAAAAAA);
    
    // 4. Overwrite edge pins to check cross-pin side effects
    // Pin 15 (bits 31:30 of reg 0) to func 3
    uint32_t val0 = REG32(IO_MUX_BASE + 0x00);
    val0 = (val0 & ~(3U << 30)) | (3U << 30);
    REG32(IO_MUX_BASE + 0x00) = val0;
    
    // Pin 16 (bits 1:0 of reg 4) to func 3
    uint32_t val1 = REG32(IO_MUX_BASE + 0x04);
    val1 = (val1 & ~(3U << 0)) | (3U << 0);
    REG32(IO_MUX_BASE + 0x04) = val1;
    
    CHECK_EQ(REG32(IO_MUX_BASE + 0x00), 0xD5555555);
    CHECK_EQ(REG32(IO_MUX_BASE + 0x04), 0xAAAAAAAB);
    // func 2 was 10 (0xA). So ...1010 becomes ...1011 (0xB)
    // Let's just read and mask to be safe instead of hardcoding the full word to avoid dumb mistakes.
    uint32_t check_p15 = (REG32(IO_MUX_BASE + 0x00) >> 30) & 3;
    uint32_t check_p16 = (REG32(IO_MUX_BASE + 0x04) >> 0) & 3;
    CHECK_EQ(check_p15, 3);
    CHECK_EQ(check_p16, 3);

    // Ensure pin 14 wasn't affected
    uint32_t check_p14 = (REG32(IO_MUX_BASE + 0x00) >> 28) & 3;
    CHECK_EQ(check_p14, 1);
    
    TEST_PASS();
}
