volatile int interrupt_fired = 0;

void __attribute__((interrupt("machine"))) trap_handler() {
    interrupt_fired = 1;
    // Disable MTIE in mie to prevent infinite trap loop since TB keeps mtip asserted for a long time
    int mie;
    __asm__ volatile("csrr %0, 0x304" : "=r"(mie));
    mie &= ~(1 << 7); // clear MTIE
    __asm__ volatile("csrw 0x304, %0" : : "r"(mie));
}

int main() {
    // 1. Set mtvec
    unsigned int trap_addr = (unsigned int)&trap_handler;
    __asm__ volatile("csrw 0x305, %0" : : "r"(trap_addr));

    // 2. Enable MTI in mie (bit 7)
    __asm__ volatile("csrw 0x304, %0" : : "r"(1 << 7));

    // 3. Enable MIE in mstatus (bit 3)
    __asm__ volatile("csrw 0x300, %0" : : "r"(1 << 3));

    // Wait for the interrupt to arrive (tb_top.sv asserts mtip at #220, which is soon)
    int timeout = 50000;
    while (!interrupt_fired && timeout > 0) {
        timeout--;
    }

    return interrupt_fired ? 0x600D : 0xBAD0;
}
