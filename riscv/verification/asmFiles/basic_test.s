.text
.globl _start

_start:
    # 1. Forwarding and Data Hazards
    addi x1, x0, 15
    addi x2, x0, 25
    add  x3, x1, x2       # RAW x1, x2. x3 = 40
    sub  x4, x3, x1       # RAW x3 (EX-EX forwarding). x4 = 25
    and  x5, x4, x2       # RAW x4 (EX-EX forwarding). x5 = 25 & 25 = 25
    or   x6, x5, x1       # RAW x5. x6 = 25 | 15 = 31
    xor  x7, x6, x5       # RAW x6. x7 = 31 ^ 25 = 6
    sll  x8, x7, x1       # RAW x7. x8 = 6 << 15 = 196608
    srl  x9, x8, x7       # RAW x8, x7. x9 = 196608 >> 6 = 3072
    sra  x10, x9, x7      # x10 = 3072 >> 6 = 48
    
    # 2. Memory Load-Use Hazards
    sw   x10, 0x20(x0)    # Store 48 at 0x20
    sw   x9,  0x24(x0)    # Store 3072 at 0x24
    lw   x11, 0x20(x0)    # Load 48 into x11
    add  x12, x11, x1     # Load-Use hazard! Pipeline must stall. x12 = 48 + 15 = 63
    
    # 3. Immediate Shifts and Extended ALU operations
    slli x13, x12, 4      # x13 = 63 << 4 = 1008
    srli x14, x13, 2      # x14 = 1008 >> 2 = 252
    srai x15, x14, 1      # x15 = 252 >> 1 = 126
    
    # Halt simulation / testbench trap
    lui x4, 0x1          # x4 = 0x1000
    sw x15, 0(x4)        # mem[0x1000] = 126
    
    # Force eviction of 0x1000 (Set 0) by loading from 0x0000 (Set 0)
    lw x5, 0(x0)
    
1:  j 1b
