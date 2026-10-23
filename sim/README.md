# Simulation and Testbenches

Run `make test`, or `python scripts/simulate.py` followed by
`python scripts/test_jtag_console.py`. GHDL must support VHDL-2008. Set `GHDL`
to an absolute executable path when necessary. No Quartus or physical cable is
needed for these checks. A failed assertion, compilation, or timeout fails the run.

| Bench | Coverage |
| --- | --- |
| `tb_alu` | Arithmetic, comparisons and shifts |
| `tb_decoder` | 270,612 legal/reserved/unknown-input cases for all 40 RV32I instructions |
| `tb_decoder_focused` | Seven readable decoder cases: ADDI/LW/SW/BEQ/JAL, illegal input and NOP recovery |
| `tb_regfile` | Write/read, reset and x0 protection |
| `tb_jtag_uart` | Fixed-latency MMIO, invalid accesses, stalled Avalon signal stability, exact TX byte ordering, full TX FIFO backpressure without starving RX, reset |
| `tb_memory_bus` | ROM fetch/data, RAM byte lanes/boundaries, instruction fetch from RAM, collision suppression, MMIO routing and response timing |
| `tb_de10_lite_top` | Actual ROM loader + CPU + RAM + adapter: upload/CRC, invalid sizes, execution from RAM, initialized data, BSS clearing, ABI return/re-run, failed replacement, reset during upload |
| `tb_core` | Independent four-instruction retirement trace, RAM store, loop, reset |
| `tb_core_execution` | Execution paths and directed architectural traps |
| `tb_core_reset` | Reset before/after store acceptance and pending writeback; request suppression, PC zero, register clearing and RAM persistence |
| `tb_core_reset_extended` | Four resets at fetch/load request and response boundaries; canceled load suppression, PC zero and clearing a previously nonzero x8 |

The board test binds `sim/jtag_uart_system.vhd` to the board wrapper's generated
IP component. This is an Avalon/FIFO model with 64-byte queues and injected
waitrequest stalls. Host signals live in `jtag_uart_sim_pkg`. Neither simulation
file is included in the Quartus project. The model tests the CPU-facing path,
not the Intel JTAG scan protocol, native library, clock-domain crossing or hardware.

The checked-in `sim/images/hello.hex` fixture is generated from `hello.S` with
the application startup/linker. `make app` regenerates it. Normal simulation
does not require a cross compiler. The fixture's entry wrapper and application
exercise both code/data access from executable RAM and return to the loader.

The 14 generated directed programs compare independent expected retirement
traces, destination values, traps, request counts and reset recovery. Coverage
includes all load/store widths and lanes, signed extension, x0 side effects,
ALU/shift boundaries, branches/JALR, alignment, ROM writes, and rejected MMIO.
The mixed RAM loop adds five iterations of arithmetic, a backward BNE, stores
and loads, checking 41 retirements, 15 data requests and final words 1/3/6/10/15.

Five host tests cover padding/CRC, fragmented responses, maximum 12 KiB image,
32-byte credit pacing, rejected CRC, no-image error, invalid sizes and timeouts.
They use an independent protocol peer; native USB-Blaster communication is not
claimed. The board bench separately exercises the actual C loader and RV32I machine code.

`make test-adapter` additionally checks local architectural pass/fail/trap/timeout
paths. It uses LLVM by default or GNU tools with exported `RISCV_PREFIX`.
No upstream architectural certification suite has run. Remaining CPU work
includes broader uploaded mixed programs and reset coverage across every core state.

`python scripts/report4_evidence.py` repeats the regression and host checks and
saves focused GHW/VCD traces, assertion transcripts and PNG waveforms under
`docs/progress_reports/evidence`. Pillow is needed only for the PNG renderer.
The GHW files preserve VHDL enumeration/record types; the decoder VCD exposes
enum-position aliases (`kind_code`, `size_code`, etc.) in package declaration
order. The PNG labels translate those actual trace values. See
`docs/progress_reports/evidence/report-4-completion.md` for waveform explanations.

`python scripts/report6_evidence.py` saves the extended reset and mixed-loop
GHW/VCD traces, independent program image/reference trace, measured store
results, waveform PNGs, regression/host/adapter logs and Quartus tool preflight.
It requires GHDL, Pillow and a RISC-V compiler for the adapter self-test;
set `GHDL` and `RISCV_PREFIX` when those tools are not on PATH.
See `docs/progress_reports/evidence/report-6-completion.md` for the dated results.
