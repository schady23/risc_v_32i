# RV32I CPU for the DE10-Lite

A non-pipelined, multi-cycle VHDL-2008 RV32I CPU for the Terasic DE10-Lite's
MAX 10 `10M50DAF484C7G`. All software I/O uses **JTAG UART through the existing
USB-Blaster**. No serial adapter, GPIO wiring, COM port, or baud setting is used.

The ROM boots a program loader. Assemble a program on your computer, upload
it into executable RAM, and run it without rebuilding the FPGA configuration.
Programs can print through JTAG UART and return to the loader.

## Quick start

With GHDL, Python 3, a bare-metal RISC-V GCC toolchain, and Quartus Prime
Lite/Standard with MAX 10 and Platform Designer support:

```sh
make test       # CPU, bus, JTAG adapter, loader integration, and host protocol
make image      # Rebuild ROM loader (the generated ROM is also checked in)
make app        # Build the uploadable hello and mixed-RAM examples
make build      # Generate Intel JTAG UART IP, compile FPGA, check timing
make program    # Program the fresh .sof through USB-Blaster
python -m pip install -r software/requirements.txt
python scripts/jtag_console.py upload software/build/hello.bin --run
```

Expected application output:

```text
RUN
Hello from uploaded RV32I assembly!
EXIT 0000002A
ready>
```

Subsequent program changes require only assembly and upload. Use
`python scripts/jtag_console.py console` for a line-oriented console, or
`python scripts/jtag_console.py run` to run the loaded image again. Close other
JTAG UART terminals first. Press `KEY(0)` if a program traps, hangs, or an upload
is interrupted. Reset returns to the loader and requires a new upload.

See [JTAG UART and loader setup](docs/uart.md) for host libraries, cable selection,
assembly conventions, transfer details, recovery, and the memory map.

## Tools without Make

```sh
python scripts/build_software.py --prefix riscv64-unknown-elf-
python scripts/build_app.py software/hello.S --test-image sim/images/hello.hex
python scripts/build_app.py software/mixed_ram.S --test-image sim/images/mixed_ram.hex
python scripts/simulate.py
python scripts/test_jtag_console.py
quartus_sh -t scripts/build.tcl
quartus_sh -t scripts/program.tcl
```

The compiler prefix can include a full directory. Export `RISCV_PREFIX` to use
a different prefix throughout the Python tools; set `GHDL` to select an
executable not on PATH. `make image`/`make app` use the Python build tools, so
the same commands work on Windows. On Windows `PYTHON=python` can override
Make's default `python3`.

The Python JTAG helper uses the MIT-licensed `intel-jtag-uart` binding and the
Quartus `jtag_atlantic` / `jtag_client` libraries. Specify
`--quartus-root C:/path/to/quartus` before the subcommand when necessary.

## Memory and I/O

| Range/address | Use |
| --- | --- |
| `0x00000000`-`0x00003FFF` | 16 KiB ROM: loader, startup and constants |
| `0x00010000`-`0x00012FFF` | 12 KiB application code/data/BSS |
| `0x00013000`-`0x00013BFF` | 3 KiB application stack |
| `0x00013C00`-`0x00013FFF` | 1 KiB loader workspace/stack |
| `0x40000000` | TX staging byte, `SW` only |
| `0x40000004` | RX staging byte, `LW` only; consumes byte |
| `0x40000008` | Status, `LW` only: TX-ready bit 0, RX-ready bit 1, TX-pending bit 2 |

RAM supports both instruction fetch and data accesses through its existing
single port. This multi-cycle CPU never needs them simultaneously. UART MMIO
remains a fixed one-cycle response; staging buffers handle Intel IP's variable
Avalon waitrequest without changing the CPU's bus protocol.

The memory regions are software conventions, without hardware protection.
Application startup preserves the loader's ABI state, switches stacks, clears
BSS, calls `main`, and restores loader state when `main` returns. Initialized
application data is included directly in the uploaded RAM image.

## Verification status

- Eleven fixed GHDL benches and 14 directed programs pass, including 270,612
  decoder cases and CPU/ROM/RAM/adapter upload/run/CRC/return/reset integration.
- Five host uploader tests pass, including a maximum-size image, chunk credits,
  fragmented responses, CRC rejection, and timeout handling.
- The local architectural adapter's pass/fail/trap/timeout checks pass using GNU
  tools. Upstream architectural certification remains pending.
- GHDL synthesis accepts `rv32i_system` (the vendor-independent system).
- Intel JTAG UART IP generation, full Quartus compilation, and timing checks
  pass with Quartus Prime Lite 25.1. All paths are constrained under the
  documented JTAG I/O assumptions. Physical USB-Blaster upload, CRC verification,
  execution and rerun of hello and mixed_ram are documented on October 29.
  Recorded reset/error-recovery checks remain pending. The GHDL model represents
  the Intel IP's Avalon/FIFO interface, not the JTAG pins.

See the [JTAG verification record](docs/validation/2026-10-14-jtag/README.md)
and the [October 15 decoder/reset evidence](docs/progress_reports/evidence/report-4-completion.md).
The [October 23 reset and mixed-program evidence](docs/progress_reports/evidence/report-6-completion.md)
adds four fetch/load reset cases and a five-iteration RAM loop with final readback.
The [October 29 Quartus preparation record](docs/validation/2026-10-29-quartus-prep/README.md)
records current Intel IP generation, analysis/elaboration, rebuilt loader,
and upload/re-run simulation of the second assembly application.
The [October 29 JTAG timing correction](docs/validation/2026-10-29-jtag-timing/README.md)
records the successful full build, timing margins, JTAG I/O assumptions, and
fresh programming-file hash.
The [October 29 board evidence](docs/validation/2026-10-29-board/README.md)
records the successful physical uploads/reruns and the recovery checks carried
forward into Progress Report 7.
The archived September GPIO and earlier October physical-UART results describe
previous designs; their utilization, timing and SOF files do not validate this one.

## Documentation and source layout

- [Illustrated user guide](docs/user_guide/rv32i_user_guide.docx): Windows setup,
  equipment and safety, simulation, FPGA programming, application upload and troubleshooting.
- [Architecture contract](docs/architecture.md): ISA, state machine, memory timing,
  instruction/data routing, MMIO and traps.
- [Board bring-up](docs/bringup.md): generated IP, constraints, compilation and programming.
- [JTAG UART and loader](docs/uart.md): upload and application workflow.
- [Simulation](sim/README.md) and [architectural adapter](sim/arch-test/README.md).
- [Progress Report 4](<docs/progress_reports/Progress Report 4 rschader.docx>) and
  [Progress Report 5](<docs/progress_reports/Progress Report 5 rschader.docx>):
  architecture review, decoder/reset waveforms and updated schedules.
- [Progress Report 6](<docs/progress_reports/Progress Report 6 rschader.docx>):
  extended reset and mixed-program results, the October 23 Quartus blocker, and
  new build, DE10-Lite test and uploaded-application goals.
- [Progress Report 7](<docs/progress_reports/Progress Report 7 rschader.docx>):
  current build/timing results, board photo, application console screenshot,
  previous and updated schedules, and recovery/documentation/final-report goals.

`rtl/core/` contains the CPU; `rtl/memory/` contains ROM and RAM;
`rtl/interconnect/` routes requests; `rtl/peripheral/` contains the JTAG adapter;
`rtl/board/` contains the system and board wrappers. Intel IP is generated under
the ignored `build/ip/` directory. `software/` contains the ROM loader and
uploadable examples. `scripts/` contains build, upload, verification and diagram tools.
