.text
.globl _start

_start:
    li x1, 10          # loop count (10)
    li x2, 0           # sum
    li x3, 0           # iterator
loop:
    add x2, x2, x3
    addi x3, x3, 1
    blt x3, x1, loop

    # x2 should be 0+1+2+3+4+5+6+7+8+9 = 45 = 0x2D
    lui x4, 0x1        # 0x1000
    sw x2, 0(x4)       # mem[0x1000] = 45
    
    # Force eviction of 0x1000 (Set 0) by loading from 0x0000 (Set 0)
    lw x5, 0(x0)
    
1:  j 1b
