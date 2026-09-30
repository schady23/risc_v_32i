# RV32I CPU for the DE10-Lite

A VHDL-2008 implementation of a non-pipelined, multi-cycle RV32I CPU targeting
the Terasic DE10-Lite. The board uses a MAX 10 `10M50DAF484C7G` FPGA; see
[Terasic's board specifications](https://www.terasic.com.tw/cgi-bin/page/archive.pl?CategoryNo=218&Language=English&No=1021&PartNo=2).

The multi-cycle core, memory bus, and GPIO are connected to the DE10-Lite top
level. The checked-in ROM contains a four-instruction demo that writes
`0x155` to the ten LEDs and loops. Simulation and the integrated Quartus build pass, including 50 MHz timing
checks. Physical board validation remains pending; no JTAG hardware was detected.

## Documentation

- [Architecture contract](docs/architecture.md): ISA, memory timing, address map,
  reset, traps, retirement, and the DE10-Lite integration contract.
- [DE10-Lite bring-up](docs/bringup.md): hardware/tool requirements, build
  commands, programming instructions, and validation results.
- [Simulation and testbenches](sim/README.md): runnable GHDL commands, current
  coverage, and verification milestones.
- [Architectural tests](sim/arch-test/README.md): local binary adapter and remaining upstream integration.

## Current implementation

| Component | Status |
| --- | --- |
| Shared packages | Types, ALU operations, core states, trap codes, and memory map defined |
| ALU | All ten operations implemented; boundary execution checks pass |
| Register file | Two read ports, synchronous write/reset, and protected `x0` implemented |
| Decoder | All 40 RV32I instructions decoded; legality, immediates, and typed execution controls tested |
| Core | Multi-cycle execution, retirement trace, alignment/access traps, and halt on fault implemented |
| ROM, RAM, memory bus, GPIO | Synchronous implementations with directed access and byte-lane checks |
| Board support | CPU system top level, pin/timing constraints, Quartus build and JTAG scripts |
| Simulation | Seven fixed benches plus 13 directed programs; 270,612 decoder cases |

## Repository layout

```text
constraints/  DE10-Lite pin assignments and 50 MHz timing constraints
docs/         Architecture and DE10-Lite bring-up documentation
rtl/pkg/      Shared CPU types/constants and memory map
rtl/core/     ALU, register file, decoder, and multi-cycle core
rtl/memory/   Program image, instruction ROM, and data RAM
rtl/interconnect/  Fixed-latency memory bus
rtl/peripheral/    Memory-mapped GPIO
rtl/board/    Reset synchronizer and DE10-Lite CPU wrapper
scripts/      Quartus build/programming, GHDL runner, and image converter
sim/          Testbenches, directed assembly programs, and test documentation
software/     Linker script, startup code, smoke program, and Makefile
```

## Development workflow

From the repository root:

```sh
make test       # Run seven fixed benches and 13 directed programs
make build      # Generate the Quartus project, compile, and check timing
make test-adapter # Check local adapter pass/fail/trap/timeout paths (LLVM required)
```

Use Quartus Prime Lite or Standard with MAX 10 support installed; see the
[Quartus edition comparison](https://www.intel.com/content/www/us/en/products/details/fpga/development-tools/quartus-prime/resource.html).
The build creates `build/quartus/risc_v_32i.qpf` and
`build/quartus/output_files/risc_v_32i.sof`. Timing and utilization reports are
written under `build/reports/`. The integrated CPU build passed with Quartus
Prime Lite 25.1 on September 30, 2026 (985 logic elements, 20 M9Ks).
See [validation results](docs/bringup.md#validation-results).

With a DE10-Lite connected, use the [JTAG instructions](docs/bringup.md#configure-the-board-through-jtag)
to select the cable and run `make program`. The checked-in CPU demo writes
`0x155` to the LEDs and restarts when `KEY(0)` is pressed. Switch inputs are
available through memory-mapped GPIO.

`make project` generates the project without compiling; `make timing` rechecks
an existing compilation. Project settings are generated from tracked scripts,
so edit those scripts rather than the generated QSF. All testbenches live in
[`sim/`](sim/README.md).

## Software image

From the repository root, with GNU Make, Python 3, and a bare-metal GNU RISC-V
toolchain installed:

```sh
make -C software
python3 scripts/elf_to_vhdl.py software/build/smoke.bin \
  rtl/memory/program_image_pkg.vhd
```

Override the toolchain prefix when necessary:

```sh
make -C software RISCV_PREFIX=riscv32-unknown-elf-
```

The Makefile targets `-march=rv32i -mabi=ilp32`; its default prefix is
`riscv64-unknown-elf-`. Despite its filename, `elf_to_vhdl.py` accepts a flat
little-endian binary, not an ELF file. It replaces the checked-in program-image
package, pads the last word, and rejects images larger than 16 KiB. Recompile
simulation or FPGA sources after generating a new image.

The board integration preserves the ROM/RAM addresses and GPIO register
addresses. The CPU displays the low ten LED-register bits. The current startup
sets the stack and clears `.bss`, but does not copy initialized `.data` from ROM
to RAM; add that support before relying on initialized writable variables.
`make image` replaces the checked-in demo with the assembled software image;
rebuild the simulation and FPGA project afterward.

## Next milestones

1. Program a DE10-Lite and verify the LED demo and reset behavior.
2. Extend mixed-program tests and reset coverage across every core state.
3. Complete shared image loading, initialized data, and ACT4 platform inputs.
4. Run compatible upstream architectural tests and document results/exclusions.
