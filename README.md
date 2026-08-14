# RV32I CPU for the Basys 3

This repository is a VHDL-2008 scaffold for a multi-cycle RV32I CPU targeting
the Digilent Basys 3 (`xc7a35tcpg236-1`). The design is intentionally staged:
the current top level is a board smoke test, while the architectural contracts
for the CPU, memory system, traps, and retirement trace are fixed in
[`docs/architecture.md`](docs/architecture.md).

## Current status

- Project layout and architecture contract are defined.
- Basys 3 clock, button, switch, and LED constraints are present.
- Reset synchronization and a synthesizable board smoke top are implemented.
- Common RV32I and memory-map packages are present.
- CPU, decoder, memories, interconnect, GPIO, and testbench files are compileable
  scaffolds or initial building blocks, not a complete processor.
- The smoke top mirrors `sw(14 downto 0)` onto `led(14 downto 0)` and blinks
  `led(15)` from the 100 MHz board clock. Pressing `btnC` clears the LEDs.

## Repository layout

```text
constraints/  Basys 3 pin and timing constraints
docs/         Architecture and board bring-up documentation
rtl/          VHDL packages, core, memories, peripherals, and board wrapper
scripts/      Vivado and program-image generation scripts
sim/          VHDL testbenches and assembly test programs
software/     Linker script, startup code, and cross-compilation Makefile
```

## Vivado smoke build

From a Vivado Tcl shell in the repository root:

```tcl
source scripts/create_project.tcl
source scripts/build.tcl
```

The generated project is placed under `build/vivado/`; generated files are not
tracked. See [`docs/bringup.md`](docs/bringup.md) for programming instructions.

## Software image

The software scaffold expects a GNU RISC-V ELF toolchain:

```sh
make -C software
python scripts/elf_to_vhdl.py software/build/smoke.bin \
  rtl/memory/program_image_pkg.vhd
```

`RISCV_PREFIX` may be overridden if the toolchain uses a prefix other than
`riscv64-unknown-elf-`.

## Implementation order

1. Verify the board smoke build and reset behavior.
2. Complete and unit-test the ALU, register file, and decoder.
3. Complete the fixed-latency memories and memory bus.
4. Implement the multi-cycle core FSM and retirement trace.
5. Run hand-written programs, then RISC-V architectural tests.
6. Replace the smoke logic in `basys3_top.vhd` with the integrated CPU system.
