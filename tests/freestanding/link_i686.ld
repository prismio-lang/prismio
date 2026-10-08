/* A 32-bit x86 kernel that QEMU's `-kernel` loader accepts: an ELF32 image with a
   Xen PVH entry note, which the loader reads from the note segment. */
ENTRY(_start)

SECTIONS {
    . = 1M;
    .note   : SUBALIGN(4) { *(.note.Xen) }
    .text   : { *(.text.boot) *(.text .text.*) }
    .rodata : { *(.rodata .rodata.*) }
    .data   : { *(.data .data.*) }
    .bss    : { *(.bss .bss.*) *(COMMON) }
    . = ALIGN(16);
    . += 0x4000;
    __stack_top = .;
}
