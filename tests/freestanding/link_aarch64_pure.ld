/* The same board, with the stack named here instead of reserved in C: a kernel
   written entirely in Prismio has no C file to hold an array. */
ENTRY(_start)

SECTIONS {
    . = 0x40080000;
    .text   : { *(.text.boot) *(.text .text.*) }
    .rodata : { *(.rodata .rodata.*) }
    .data   : { *(.data .data.*) }
    .bss    : { *(.bss .bss.*) *(COMMON) }
    . = ALIGN(16);
    . += 0x4000;
    __stack_top = .;
}
