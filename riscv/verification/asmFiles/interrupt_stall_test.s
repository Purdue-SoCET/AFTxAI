.section .text.init
.globl _start

_start:
    # Setup MTVEC
    la t0, trap_handler
    csrw mtvec, t0

    # Initialize counter
    li x1, 0

    # Enable M-mode interrupts (MIE=1 in mstatus) and MTI in mie
    li t0, 0x8       # mstatus.MIE is bit 3
    csrw mstatus, t0
    li t0, 0x80      # mie.MTIE is bit 7
    csrw mie, t0

loop:
    # We want x1 to increment. If interrupted, we might see it increment twice?
    # Wait, the bug is: instruction in WB writes to reg file, but then gets squashed by interrupt.
    # So it writes to reg file, and when we return from interrupt, we RE-EXECUTE it, writing AGAIN.
    addi x1, x1, 1
    addi x2, x0, 2
    addi x3, x0, 3
    # Try to cause a stall.
    # A load instruction will cause a stall in the stage BEFORE it while it fetches?
    # No, load from a new cache line causes global stall.
    lw x4, 128(x0)
    
    j loop

trap_handler:
    # Disable MTI
    li t0, 0
    csrw mie, t0
    
    # Write x1 to 0x1000 so testbench intercepts and prints it
    # We expect x1 to be some value.
    lui t0, 1
    sw x1, 0(t0)
    
    mret
