#include "../include/aft_map.h"

int main() {
    // 1. Basic configuration checks
    REG32(UART_BASE + 0x08) = 115200; // Baud rate config
    CHECK_EQ(REG32(UART_BASE + 0x08), 115200);

    REG32(UART_BASE + 0x0C) = 0x3; // LCR: 8-N-1 config
    CHECK_EQ(REG32(UART_BASE + 0x0C), 0x3);

    // 2. Transmit a string, waiting for TX FIFO space
    const char *msg = "UART Comprehensive Test\n";
    while(*msg) {
        int timeout = 10000;
        // Wait until TX Full bit (e.g., bit 0 in Status Register at 0x04) is clear
        while((REG32(UART_BASE + 0x04) & 0x1) != 0 && timeout > 0) {
            timeout--;
        }
        CHECK_NEQ(timeout, 0); // Fail if TX FIFO remains full (timeout)
        
        // Write char to TX Data Register (0x00)
        REG32(UART_BASE + 0x00) = *msg++;
    }

    // 3. Clear pending interrupts (Assume offset 0x10)
    REG32(UART_BASE + 0x10) = 0xFFFFFFFF;
    
    TEST_PASS();
}
