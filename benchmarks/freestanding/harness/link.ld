/* QEMU `virt`: RAM at 0x40000000, the image where its -kernel loader puts it. The
   stack is 1 MiB, and the scratch regions the hardware workloads use start at
   0x44000000, well clear of both. */
ENTRY(_start)

SECTIONS {
    . = 0x40080000;
    .text   : { *(.text.boot) *(.text .text.*) }
    .rodata : { *(.rodata .rodata.*) }
    .data   : { *(.data .data.*) }
    .bss    : { *(.bss .bss.*) *(COMMON) }
    . = ALIGN(16);
    . += 0x100000;
    __stack_top = .;
}
