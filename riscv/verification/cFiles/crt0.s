.section .text.init
.globl _start

_start:
    # Initialize stack pointer to end of 8KB RAM (8192)
    li sp, 8192
    
    # Call main C function
    call main

    # Store return value (in a0 / x10) to 0x1000
    lui t0, 1
    sw a0, 0(t0)

    # Force eviction of 0x1000 cache line (assuming directly mapped and reading 0 conflicts)
    lw t1, 0(zero)
    
1:  j 1b
