OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY {
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 8K
}

SECTIONS {
    .text : {
        *(.text.init)
        *(.text*)
        *(.rodata*)
    } > RAM

    .data : {
        *(.data*)
        *(.sdata*)
    } > RAM

    .bss : {
        __bss_start = .;
        *(.bss*)
        *(.sbss*)
        __bss_end = .;
    } > RAM
}
