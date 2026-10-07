    .section .text.init
    .globl _start
_start:
    # Set up stack and pointers
    la sp, stack_top
    csrr t0, mhartid
    bnez t0, core1_amo

core0_amo:
    # Test LR.W / SC.W (Lock)
    la a0, shared_lock
    li a1, 1

1:
    lr.w t1, (a0)
    bnez t1, 1b       # lock is held by other, retry
    sc.w t2, a1, (a0)
    bnez t2, 1b       # store-conditional failed, retry
    
    # Critical section for Core 0
    la a2, shared_counter
    amoadd.w t3, a1, (a2)   # Atomic increment

    # Release lock (AMO or store)
    amoswap.w zero, zero, (a0)
    
    # Other AMOs
    la a3, amo_target
    li t4, 0x5
    amoxor.w t5, t4, (a3)
    li t4, 0x3
    amoand.w t6, t4, (a3)
    amoor.w  t6, t4, (a3)
    
    j pass

core1_amo:
    # Wait a bit then try to grab the lock
    li t0, 10
2:  addi t0, t0, -1
    bnez t0, 2b

    la a0, shared_lock
    li a1, 1
1:
    lr.w t1, (a0)
    bnez t1, 1b
    sc.w t2, a1, (a0)
    bnez t2, 1b
    
    # Critical section for Core 1
    la a2, shared_counter
    amoadd.w t3, a1, (a2)

    # Release lock
    amoswap.w zero, zero, (a0)

    j pass

pass:
    j pass
fail:
    j fail

    .section .data
    .align 4
shared_lock:
    .word 0x0
shared_counter:
    .word 0x0
amo_target:
    .word 0xFFFF
stack_top:
    .space 256
