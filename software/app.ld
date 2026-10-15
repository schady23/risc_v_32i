OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY { APP (rwx) : ORIGIN = 0x00010000, LENGTH = 12K }
SECTIONS {
  .text : { KEEP(*(.text.init)) *(.text .text.*) *(.rodata .rodata.*) } > APP
  .data : { *(.data .data.* .sdata .sdata.*) } > APP
  .bss (NOLOAD) : {
    . = ALIGN(4); __bss_start = .;
    *(.bss .bss.* .sbss .sbss.* COMMON)
    . = ALIGN(4); __bss_end = .;
  } > APP
  __stack_top = 0x00013C00;
  ASSERT(_start == ORIGIN(APP), "Application entry must be 0x10000")
  ASSERT(__bss_end <= 0x00013000, "Application exceeds its 12 KiB region")
}
