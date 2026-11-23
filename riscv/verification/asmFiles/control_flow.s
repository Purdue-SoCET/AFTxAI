.text
.globl _start

_start:
    # Initialize stack pointer 
    li sp, 0x400

    # Test jal and jalr
    li a0, 5           # arg1 for outer_loop
    jal ra, outer_loop
    
    # Testbench halt
    lui x4, 0x1        # 0x1000
    sw a0, 0(x4)       # Save final result
    
    # Force eviction of 0x1000 (Set 0) by loading from 0x0000 (Set 0)
    lw x5, 0(x0)
    
1:  j 1b

# Function outer_loop
# nested loops using different branch conditions
outer_loop:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    sw s1, 4(sp)
    
    mv s0, a0          # s0 = 5 (outer loop count)
    li s1, 0           # s1 = total sum
    
o_loop:
    beq s0, zero, o_done  # branch if equal
    
    # inner loop
    li t0, 3           # inner loop count
i_loop:
    add s1, s1, s0     # sum += outer_count
    addi t0, t0, -1
    bne t0, zero, i_loop  # branch if not equal
    
    addi s0, s0, -1
    bge s0, zero, skip_neg  # test bge
    
    # Unreachable but tests jump
    j o_done
skip_neg:
    j o_loop           # jump back
    
o_done:
    mv a0, s1          # a0 = sum (expected: 5*3 + 4*3 + 3*3 + 2*3 + 1*3 = 45)
    
    lw s1, 4(sp)
    lw s0, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    jalr zero, 0(ra)   # return using jalr
