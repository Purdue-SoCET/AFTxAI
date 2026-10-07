    .section .text.init
    .globl _start
_start:
    # Core divergence: reading mhartid (Zicsr)
    csrr t0, mhartid
    bnez t0, core1_start

core0_start:
    # Basic ALU tests
    li t1, 0x1234
    li t2, 0x5678
    add a0, t1, t2
    sub a1, t2, t1
    xor a2, t1, t2
    and a3, t1, t2
    or  a4, t1, t2
    slli a1, t1, 4
    srli a2, t2, 4
    srai a3, t2, 4

    # Memory loads/stores
    la a5, test_data
    sw a0, 0(a5)
    lw t0, 0(a5)
    
    # Branching
    beq a0, t0, branch_pass
    j fail

branch_pass:
    li t1, 10
    li t2, 20
    blt t1, t2, blt_pass
    j fail

blt_pass:
    # Jumps
    jal ra, func_call
    
    # Fences
    fence
    fence.i
    
    j pass

func_call:
    # Test simple return
    addi sp, sp, -16
    sw ra, 12(sp)
    # do something
    li t0, 0xDEADBEEF
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

core1_start:
    # Core 1 separate test logic
    li t1, 0xC08E1
    li t2, 0x1111
core1_loop:
    j core1_loop

pass:
    j pass

fail:
    j fail

    .section .data
    .align 4
test_data:
    .word 0x0
