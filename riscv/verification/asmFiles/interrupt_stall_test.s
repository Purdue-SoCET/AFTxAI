.section .text.init
.globl _start

_start:
    # Setup MTVEC
    la t0, trap_handler
    csrw mtvec, t0

    # Initialize counters and state
    li x1, 0
    li x10, 0
    li x11, 0

    # Enable M-mode interrupts (MIE=1 in mstatus) and MTI in mie
    li t0, 0x8       # mstatus.MIE is bit 3
    csrw mstatus, t0
    li t0, 0x80      # mie.MTIE is bit 7
    csrw mie, t0

loop:
    # Complex instruction mix to stress pipeline when interrupt fires
    # 1. Back-to-back ALU (EX-EX forwarding)
    addi x1, x1, 1
    add  x2, x1, x1
    xor  x3, x2, x1
    
    # 2. Load-use hazard to trigger stalls 
    sw   x3, 0x100(x0)
    lw   x4, 0x100(x0)
    add  x5, x4, x1      # Stall cycle here!
    
    # 3. Multi-cycle delay load to cause cache miss / longer stall
    lw   x6, 128(x0)
    
    # 4. Branches to test squashing during interrupt
    blt  x1, zero, skip
    addi x10, x10, 1     # Branch not taken path
skip:
    bge  x1, zero, loop
    # Unreachable
    j loop

trap_handler:
    # Disable MTI to prevent nested traps in basic handler
    li t0, 0
    csrw mie, t0
    
    # Perform CSR reads/writes within the trap
    csrr t1, mepc
    csrr t2, mcause
    
    # Write x1 and x10 to 0x1000 so testbench intercepts and prints it
    lui t0, 1
    sw x1, 0(t0)
    sw x10, 4(t0)
    
    mret
