.section .text
.globl _start

_start:
    // Set stack pointer (assuming memory starts at 0, stack at 0x4000)
    li sp, 0x4000

    // Load array address and size
    la a0, array
    li a1, 0           // low = 0
    li a2, 9           // high = 9 (array of 10 elements)
    call quicksort

    // Signal completion: write 1 to address 0x8000
    li t0, 0x8000
    li t1, 1
    sw t1, 0(t0)

loop:
    j loop

quicksort:
    // Arguments: a0 = arr base, a1 = low, a2 = high
    bge a1, a2, qs_end // if low >= high, return

    // Prologue
    addi sp, sp, -16
    sw ra, 12(sp)
    sw a1, 8(sp)
    sw a2, 4(sp)

    // Partition
    // pivot = arr[high]
    slli t0, a2, 2
    add t0, a0, t0     // addr of arr[high]
    lw t1, 0(t0)       // pivot = arr[high]

    addi t2, a1, -1    // i = low - 1
    mv t3, a1          // j = low

partition_loop:
    bge t3, a2, partition_end

    // if arr[j] < pivot
    slli t4, t3, 2
    add t4, a0, t4     // addr of arr[j]
    lw t5, 0(t4)       // arr[j]

    bge t5, t1, partition_next // if arr[j] >= pivot, skip

    // i++
    addi t2, t2, 1
    // swap arr[i], arr[j]
    slli t6, t2, 2
    add t6, a0, t6     // addr of arr[i]
    lw a3, 0(t6)       // temp = arr[i]
    sw t5, 0(t6)       // arr[i] = arr[j]
    sw a3, 0(t4)       // arr[j] = temp

partition_next:
    addi t3, t3, 1
    j partition_loop

partition_end:
    // swap arr[i+1], arr[high]
    addi t2, t2, 1
    slli t6, t2, 2
    add t6, a0, t6     // addr of arr[i+1]
    lw a3, 0(t6)       // temp = arr[i+1]
    
    slli t0, a2, 2
    add t0, a0, t0     // addr of arr[high]
    lw t5, 0(t0)       // arr[high]

    sw t5, 0(t6)       // arr[i+1] = arr[high]
    sw a3, 0(t0)       // arr[high] = temp

    // pi = t2
    sw t2, 0(sp)       // save pi

    // quicksort(arr, low, pi - 1)
    lw a1, 8(sp)       // restore low
    addi a2, t2, -1    // pi - 1
    call quicksort

    // quicksort(arr, pi + 1, high)
    lw t2, 0(sp)       // restore pi
    addi a1, t2, 1     // pi + 1
    lw a2, 4(sp)       // restore high
    call quicksort

    // Epilogue
    lw ra, 12(sp)
    addi sp, sp, 16
qs_end:
    ret

.data
.align 2
array:
    .word 45, 12, 89, 3, 24, 76, 53, 91, 18, 62
array_end:
