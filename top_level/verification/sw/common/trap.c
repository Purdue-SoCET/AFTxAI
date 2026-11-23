#include <stdint.h>
#include "../include/aft_map.h"

// Weak default trap handler
__attribute__((weak)) uint32_t handle_trap(uint32_t mcause, uint32_t mepc) {
    // If it's an interrupt (mcause bit 31 is set)
    if (mcause & 0x80000000) {
        // Just return mepc to continue
        return mepc;
    }
    
    // For synchronous exceptions, advance mepc by 4 to skip the faulting instruction
    return mepc + 4;
}
