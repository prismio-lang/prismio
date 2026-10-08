/* QEMU `virt` loads RAM at 0x40000000; 0x40080000 is where its -kernel loader
   places an image, and where firmware conventionally hands over. */
ENTRY(_start)

SECTIONS {
    . = 0x40080000;
    .text   : { *(.text.boot) *(.text .text.*) }
    .rodata : { *(.rodata .rodata.*) }
    .data   : { *(.data .data.*) }
    .bss    : { *(.bss .bss.*) *(COMMON) }
}
