#include <stdint.h>
#include "../include/aft_map.h"

volatile int test_phase = 0;

static inline uint32_t read_mstatus() {
    uint32_t val;
    __asm__ volatile ("csrr %0, mstatus" : "=r"(val));
    return val;
}

static inline void write_mstatus(uint32_t val) {
    __asm__ volatile ("csrw mstatus, %0" : : "r"(val));
}

static inline uint32_t read_mie() {
    uint32_t val;
    __asm__ volatile ("csrr %0, mie" : "=r"(val));
    return val;
}

static inline void write_mie(uint32_t val) {
    __asm__ volatile ("csrw mie, %0" : : "r"(val));
}

static inline uint64_t read_mtime() {
    uint32_t mtime_lo = REG32(CLINT_BASE + 0xBFF8);
    uint32_t mtime_hi = REG32(CLINT_BASE + 0xBFFC);
    return ((uint64_t)mtime_hi << 32) | mtime_lo;
}

static inline void write_mtimecmp(uint64_t val) {
    REG32(CLINT_BASE + 0x4000) = 0xFFFFFFFF; // prevent spurious interrupt
    REG32(CLINT_BASE + 0x4004) = (uint32_t)(val >> 32);
    REG32(CLINT_BASE + 0x4000) = (uint32_t)val;
}

uint32_t handle_trap(uint32_t mcause, uint32_t mepc) {
    if (mcause & 0x80000000) {
        uint32_t exception_code = mcause & 0x7FFFFFFF;
        if (exception_code == 7) { // Machine Timer Interrupt
            write_mtimecmp(0xFFFFFFFFFFFFFFFFull); // clear timer
            test_phase = 1;
        } else if (exception_code == 11) { // Machine External Interrupt
            uint32_t claim = REG32(PLIC_BASE + 0x200004);
            if (claim == IRQ_DMA) {
                // Clear DMA interrupt by reading SR
                volatile uint32_t sr = REG32(DMA_BASE + 0x14);
                test_phase = 2;
            }
            // Complete the interrupt
            REG32(PLIC_BASE + 0x200004) = claim;
        }
        return mepc; // continue execution
    }
    
    // For synchronous exceptions, advance mepc by 4
    return mepc + 4;
}

void uart_print(const char *msg) {
    while(*msg) {
        while((REG32(UART_BASE + 0x14) & 0x40) == 0) {} // wait for TX ready
        REG32(UART_BASE + 0x00) = *msg++;
    }
}

int main() {
    // 1. Initialize UART
    REG32(UART_BASE + 0x1C) = 2; 
    REG32(UART_BASE + 0x0C) = 0x3; 

    uart_print("Starting Integration Test\n");

    // 2. Setup Timer Interrupt
    write_mtimecmp(read_mtime() + 500);
    write_mie(read_mie() | (1 << 7)); // MTIE
    
    // Enable Global Interrupts
    write_mstatus(read_mstatus() | (1 << 3)); // MIE

    uart_print("Waiting for Timer Interrupt...\n");
    while (test_phase == 0) { }

    uart_print("Timer Interrupt received!\n");

    // 3. Setup DMA and PLIC for external interrupt
    REG32(PLIC_BASE + 4 * IRQ_DMA) = 7; // Priority
    REG32(PLIC_BASE + 0x2000) = (1 << IRQ_DMA); // Enable IRQ_DMA for hart 0 M-mode
    REG32(PLIC_BASE + 0x200000) = 1; // Threshold

    write_mie(read_mie() | (1 << 11)); // MEIE

    uint32_t *src = (uint32_t *)(ON_CHIP_RAM_BASE + 0x2000); // 8KB offset
    uint32_t *dst = (uint32_t *)(ON_CHIP_RAM_BASE + 0x2400); // 9KB offset
    for(int i = 0; i < 32; i++) { src[i] = 0xAA550000 | i; }

    REG32(DMA_BASE + 0x04) = (uint32_t)src; 
    REG32(DMA_BASE + 0x08) = (uint32_t)dst;
    REG32(DMA_BASE + 0x0C) = 32; 
    // EN=1, PSIZE=2, INC_DEST=1, INC_SRC=1, IRQ_EN=1
    REG32(DMA_BASE + 0x10) = 0x5881; 

    uart_print("Waiting for DMA Interrupt...\n");
    int timeout = 50000;
    while (test_phase == 1 && timeout > 0) { timeout--; }
    CHECK_NEQ(timeout, 0);

    uart_print("DMA Interrupt received!\n");

    // Check DMA data
    for(int i = 0; i < 32; i++) { 
        CHECK_EQ(dst[i], src[i]); 
    }

    // 4. Test GPIO
    REG32(GPIO0_BASE + 0x08) = 0xFFFFFFFF; // DIR = output
    REG32(GPIO0_BASE + 0x04) = 0xDEADBEEF; // Data
    CHECK_EQ(REG32(GPIO0_BASE + 0x04), 0xDEADBEEF);

    uart_print("Integration Test Passed!\n");
    TEST_PASS();
}
