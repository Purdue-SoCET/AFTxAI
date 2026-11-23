#include "../include/aft_map.h"
int main() {
    for(int pin = 0; pin < 8; pin++) {
        uint32_t func = pin % 4;
        uint32_t reg_offset = (pin * 2) / 32 * 4;
        uint32_t bit_offset = (pin * 2) % 32;
        uint32_t val = REG32(IO_MUX_BASE + reg_offset);
        val = (val & ~(3 << bit_offset)) | (func << bit_offset);
        REG32(IO_MUX_BASE + reg_offset) = val; 
        uint32_t read_val = (REG32(IO_MUX_BASE + reg_offset) >> bit_offset) & 3;
        CHECK_EQ(read_val, func);
    }
    TEST_PASS();
}
