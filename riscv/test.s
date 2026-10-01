.section .text
.globl _start
_start:
    # Initialize registers
    addi x1, x0, 5      # x1 = 5
    addi x2, x0, 10     # x2 = 10
    add  x3, x1, x2     # x3 = 15
    addi x4, x0, 15     # x4 = 15
    
    beq  x3, x4, pass   # Branch to pass

fail:
    j fail

pass:
    # Store flag to memory address 0x100
    li x5, 0x100        # Address 0x100
    li x6, 0xCAFEBABE   # Flag value
    sw x6, 0(x5)        # Store 0xCAFEBABE at 0x100

    # Our dCache is Write-Back and Write-Allocate.
    # The flag is currently sitting in the cache (dirty).
    # To force it to SRAM, we can write to a conflicting cache index.
    # Cache size is 1024 (0x400) bytes. Address 0x100 + 0x400 = 0x500 maps to the same line!
    li x5, 0x500        # Conflicting address
    li x7, 0xDEADBEEF   # Another value
    sw x7, 0(x5)        # This store will cause the dCache to evict 0x100 to SRAM!

done:
    j done
