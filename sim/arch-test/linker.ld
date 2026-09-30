ENTRY(_start)
MEMORY {
    ROM (rx) : ORIGIN = 0x00000000, LENGTH = 16K
    RAM (rw) : ORIGIN = 0x00010000, LENGTH = 16K - 4
}
SECTIONS {
    .text : { *(.text.init) *(.text .text.*) *(.rodata .rodata.*) } > ROM
    .data : { *(.data .data.*) } > RAM AT > ROM
    .bss (NOLOAD) : { *(.bss .bss.*) *(COMMON) } > RAM
    __stack_top = ORIGIN(RAM) + LENGTH(RAM);
    __completion = 0x00013FFC;
    ASSERT(SIZEOF(.data) == 0, "Adapter currently requires no initialized RAM data")
}
