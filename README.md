# RV32I CPU for the DE10-Lite

A VHDL-2008 implementation of a non-pipelined, multi-cycle RV32I CPU targeting
the Terasic DE10-Lite. The board uses a MAX 10 `10M50DAF484C7G` FPGA; see
[Terasic's board specifications](https://www.terasic.com.tw/cgi-bin/page/archive.pl?CategoryNo=218&Language=English&No=1021&PartNo=2).

The DE10-Lite board smoke design, pin/timing constraints, Quartus build scripts,
and board testbench are implemented. The CPU remains under development: its
decoder is complete, but the execution core is still a scaffold. The FPGA image tests the
board's clock, reset, switches, and LEDs without executing software.

## Documentation

- [Architecture contract](docs/architecture.md): ISA, memory timing, address map,
  reset, traps, retirement, and the DE10-Lite integration contract.
- [DE10-Lite bring-up](docs/bringup.md): hardware/tool requirements, build
  commands, programming instructions, and validation results.
- [Simulation and testbenches](sim/README.md): runnable GHDL commands, current
  coverage, and verification milestones.
- [Architectural tests](sim/arch-test/README.md): future DUT adapter requirements.

## Current implementation

| Component | Status |
| --- | --- |
| Shared packages | Types, ALU operations, core states, trap codes, and memory map defined |
| ALU | All ten RV32I ALU operations implemented; directed coverage is limited |
| Register file | Two read ports, synchronous write/reset, and protected `x0` implemented |
| Decoder | All 40 RV32I instructions decoded; legality, immediates, and typed execution controls tested |
| Core | Inactive shell; no instruction execution or retirement yet |
| ROM, RAM, memory bus, GPIO | Initial synchronous implementations; broader verification needed |
| Board support | DE10-Lite smoke RTL, pin/timing constraints, Quartus build and JTAG scripts |
| Simulation | Five active testbenches, including 270,612 decoder cases; core harness still needed |

## Repository layout

```text
constraints/  DE10-Lite pin assignments and 50 MHz timing constraints
docs/         Architecture and DE10-Lite bring-up documentation
rtl/pkg/      Shared CPU types/constants and memory map
rtl/core/     ALU, register file, decoder, and core FSM scaffold
rtl/memory/   Program image, instruction ROM, and data RAM
rtl/interconnect/  Fixed-latency memory bus
rtl/peripheral/    Memory-mapped GPIO
rtl/board/    Reset synchronizer and DE10-Lite smoke wrapper
scripts/      Quartus build/programming, GHDL runner, and image converter
sim/          Testbenches, directed assembly programs, and test documentation
software/     Linker script, startup code, smoke program, and Makefile
```

## Development workflow

From the repository root:

```sh
make test       # Run the five active GHDL testbenches
make build      # Generate the Quartus project, compile, and check timing
```

Use Quartus Prime Lite or Standard with MAX 10 support installed; see the
[Quartus edition comparison](https://www.intel.com/content/www/us/en/products/details/fpga/development-tools/quartus-prime/resource.html).
The build creates `build/quartus/risc_v_32i.qpf` and
`build/quartus/output_files/risc_v_32i.sof`. Timing and utilization reports are
written under `build/reports/`. The smoke design has been compiled with Quartus
Prime Lite 25.1; see [validation results](docs/bringup.md#validation-results)
for the evidence and remaining hardware checks.

With a DE10-Lite connected, use the [JTAG instructions](docs/bringup.md#configure-the-board-through-jtag)
to select the cable and run `make program`. The image mirrors switches 0–8 on
LEDs 0–8, blinks LED 9, and resets when `KEY(0)` is pressed.

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

The board pivot preserves the ROM/RAM addresses and GPIO register addresses.
The future CPU integration will display the low ten LED-register bits. The current startup
sets the stack and clears `.bss`, but does not copy initialized `.data` from ROM
to RAM; add that support before relying on initialized writable variables.
The smoke program cannot execute until the core and board integration exist.

## Next milestones

1. Program the compiled smoke image on a DE10-Lite and verify the physical
   reset, switch, and heartbeat behavior.
2. Expand ALU and register-file edge-case tests, then connect the completed
   decoder to the execution core.
3. Verify memory byte lanes, request/response timing, and rejected accesses.
4. Implement the multi-cycle core with checked retirement and trap behavior.
5. Run directed and mixed programs, then integrate architectural tests.
6. Connect the CPU system to the DE10-Lite wrapper and run LED-visible software.
