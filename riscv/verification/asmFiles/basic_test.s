.text
.globl _start

_start:
    addi x1, x0, 10
    addi x2, x0, 20
    add x3, x1, x2       # x3 = 30
    sw x3, 0x10(x0)      # mem[0x10] = 30
    
    # Halt simulation
    lui x4, 0x1          # x4 = 0x1000
    sw x3, 0(x4)         # mem[0x1000] = 30
    
    # Force eviction of 0x1000 (Set 0) by loading from 0x0000 (Set 0)
    lw x5, 0(x0)
