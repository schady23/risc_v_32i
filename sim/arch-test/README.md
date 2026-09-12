# RISC-V Architectural Tests

## Status

Architectural tests are not integrated. The core is an inactive scaffold, and
`sim/tb_core.vhd` has no execution harness. Complete the
[directed simulation milestones](../README.md#verification-milestones) first.
Changing the target board to DE10-Lite does not change the intended ISA or
memory map defined in the [architecture contract](../../docs/architecture.md).

## Integration plan

Use the upstream [RISC-V Architectural Certification Tests](https://github.com/riscv/riscv-arch-test).
The upstream documentation currently describes ACT4, which generates
self-checking ELF tests and requires DUT configuration, platform macros, and a
linker script. Pin the selected upstream revision and record its required tools
when implementing the adapter.

Configure the DUT for RV32I, little-endian operation, `XLEN=32`, `IALIGN=32`,
no misaligned data accesses, and no optional extensions. This project has no
CSR/privileged execution environment and halts on traps. Establish which
upstream tests can run in that environment before claiming coverage; tests
requiring a privileged trap handler need a compatible adaptation or explicit
exclusion.

The adapter must provide:

- A linker layout matching the 16 KiB ROM at `0x0000_0000` and 16 KiB RAM at
  `0x0001_0000`, plus an image-loading path suitable for the simulator.
- DUT-specific completion and failure reporting, with an explicit timeout.
- Initialization of any required RAM data; the current software startup only
  clears `.bss` and does not copy `.data` from ROM.
- Result collection from test completion, memory, and retirement/trap signals,
  with failures reported to the invoking process.
- A record of the upstream revision, DUT configuration, executed tests,
  exclusions, and results.

**No writable test-status or signature MMIO register exists today.** The debug
status address `0x4000_0008` is read-only. Define a simulator-observed RAM
completion convention or a separately documented test interface before writing
the adapter; do not use that register as a writable completion mailbox.

Architectural tests complement the directed timing, alignment, trap, and
retirement checks. Passing simulations also does not replace Quartus timing
analysis or [DE10-Lite hardware bring-up](../../docs/bringup.md).
