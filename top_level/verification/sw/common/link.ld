OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    ROM (rx)  : ORIGIN = 0x00000400, LENGTH = 4K
    RAM (rwx) : ORIGIN = 0x00008400, LENGTH = 16K
}

SECTIONS
{
    .text : {
        *(.text.init)
        *(.text)
        *(.text.*)
    } > ROM

    .data : {
        *(.data)
        *(.data.*)
        *(.sdata)
        *(.rodata)
        *(.rodata.*)
    } > RAM AT> ROM

    .bss : {
        __bss_start = .;
        *(.bss)
        *(.bss.*)
        *(.sbss)
        __bss_end = .;
    } > RAM

    __stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
