.section .text.init
.globl _start

_start:
    # Initialize stack pointer to end of 8KB RAM (8192)
    li sp, 8192
    
    # Call main C function
    call main

    # Cache Flush: Read 1024 bytes (256 words) starting from 0x0000
    # to force all dirty lines in the 1KB data cache to be evicted to memory.
    li t0, 0
    li t1, 1024
flush_loop:
    lw zero, 0(t0)
    addi t0, t0, 16  # Block size is 16 bytes (4 words), step by block size
    blt t0, t1, flush_loop

    # Store return value (in a0 / x10) to 0x1000
    lui t0, 1
    sw a0, 0(t0)

    # Force eviction of 0x1000 cache line (reading 0 conflicts and evicts)
    lw t1, 0(zero)

    
1:  j 1b
