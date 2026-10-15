OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
  ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 16K
  RAM (rw)  : ORIGIN = 0x00013C00, LENGTH = 1K
}

SECTIONS
{
  .text :
  {
    KEEP(*(.text.init))
    *(.text .text.*)
    *(.rodata .rodata.*)
  } > ROM

  .data :
  {
    *(.data .data.* .sdata .sdata.*)
  } > RAM AT > ROM

  .bss (NOLOAD) :
  {
    . = ALIGN(4); __bss_start = .;
    *(.bss .bss.* .sbss .sbss.* COMMON)
    . = ALIGN(4); __bss_end = .;
  } > RAM

  __stack_top = ORIGIN(RAM) + LENGTH(RAM);
  ASSERT(_start == ORIGIN(ROM), "Reset entry must be at ROM address zero")
  ASSERT(SIZEOF(.data) == 0, "ROM loader must not use initialized writable data")
  ASSERT(__bss_end <= ORIGIN(RAM) + 128, "Leave at least 896 bytes for loader stack")
}
