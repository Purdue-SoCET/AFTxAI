    .section .text.init
    .globl _start
_start:
    # Set mtvec to point to our trap handler
    la t0, trap_vector
    csrrw zero, mtvec, t0

    # Basic CSR reads
    csrr t1, mstatus
    csrr t2, misa

    # ECALL test
    li a7, 11       # Ecall number
    ecall           # Should trap and return here
    
    # Check if a0 was updated by the trap handler
    li a1, 0x11
    bne a0, a1, fail

    # EBREAK test
    ebreak          # Should trap and return here

    # Test mcycle / minstret
    csrr a2, mcycle
    csrr a3, minstret

    j pass

    .align 4
trap_vector:
    # Save some state
    csrr a4, mcause
    
    # Check if ECALL from U-mode (8) or M-mode (11)
    li a3, 11
    beq a4, a3, handle_ecall
    
    # Check if EBREAK (3)
    li a3, 3
    beq a4, a3, handle_ebreak

    j fail

handle_ecall:
    li a0, 0x11
    # Advance mepc by 4 to skip the ecall instruction
    csrr a4, mepc
    addi a4, a4, 4
    csrw mepc, a4
    mret

handle_ebreak:
    li a0, 0x22
    # Advance mepc by 4
    csrr a4, mepc
    addi a4, a4, 4
    csrw mepc, a4
    mret

pass:
    j pass
fail:
    j fail
