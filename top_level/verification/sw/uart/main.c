#include "../include/aft_map.h"

void uart_send(const char *msg) {
    while(*msg) {
        int timeout = 10000;
        // Wait until TX FIFO is not full (bit 6 is TX Ready & Empty)
        while((REG32(UART_BASE + 0x14) & 0x40) == 0 && timeout > 0) { timeout--; }
        CHECK_NEQ(timeout, 0); 
        REG32(UART_BASE + 0x00) = *msg++;
    }
}

void uart_send_byte(uint8_t byte) {
    int timeout = 10000;
    while((REG32(UART_BASE + 0x14) & 0x40) == 0 && timeout > 0) { timeout--; }
    CHECK_NEQ(timeout, 0); 
    REG32(UART_BASE + 0x00) = byte;
}

int main() {
    // 1. Basic configuration checks
    REG32(UART_BASE + 0x1C) = 2; // Baud rate divider
    CHECK_EQ(REG32(UART_BASE + 0x1C), 2);

    REG32(UART_BASE + 0x0C) = 0x3; // LCR: 8-N-1 config
    CHECK_EQ(REG32(UART_BASE + 0x0C), 0x3);

    // 2. Transmit standard text message
    uart_send("UART Comprehensive Test Start\n");

    // 3. Transmit binary patterns (corner cases for framing)
    uint8_t patterns[] = {0x00, 0xFF, 0x55, 0xAA, 0x0F, 0xF0};
    for(int i = 0; i < 6; i++) {
        uart_send_byte(patterns[i]);
    }
    
    uart_send("\nUART Comprehensive Test Done\n");

    // 4. Change configuration on the fly and send more
    REG32(UART_BASE + 0x1C) = 4; // Change baud rate divider
    CHECK_EQ(REG32(UART_BASE + 0x1C), 4);
    
    uart_send("Baud rate changed!\n");

    // 5. Clear pending interrupts (Assume offset 0x10 is mode_ctrl_q)
    REG32(UART_BASE + 0x10) = 0xFFFFFFFF;
    
    TEST_PASS();
}
