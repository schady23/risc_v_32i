# Simulation and Testbenches

Run `make test` from the repository root with GHDL, GNU Make, Bash, and
`timeout` installed. The runner analyzes VHDL-2008 sources in order and runs
all seven fixed benches and 13 generated directed programs with assertion failures enabled.
Python 3 generates images and reference traces; the board ROM is unchanged. A failed assertion,
compilation error, or timeout gives a nonzero exit status. Set `GHDL` to select
a different executable.

| Testbench | Checked behavior |
| --- | --- |
| `tb_alu.vhd` | Representative arithmetic, comparison, and shift operations |
| `tb_decoder.vhd` | 270,612 cases covering all 40 RV32I mnemonics, immediates, controls, reserved encodings, and unknown inputs |
| `tb_regfile.vhd` | Register write/read and `x0` protection |
| `tb_memory_bus.vhd` | ROM fetch/read boundaries, RAM word and byte lanes, GPIO reads/writes, rejected writes, and response timing |
| `tb_de10_lite_top.vhd` | CPU LED demo, button reset, and program restart |
| `tb_core.vhd` | Checked retirement trace for the built-in LED demo, GPIO store, loop, and reset |
| `tb_core_execution.vhd` | Arithmetic, untaken branch, jump, RAM load/store, and directed traps |

The built-in program in `rtl/memory/program_image_pkg.vhd` writes `0x155` to
the LED register and loops. The `make image` target replaces it with assembled
software, so some expected values in these tests must be updated if that image
is committed.

The current suite does not cover every RV32I execution combination. Remaining tests should cover reset from every core state, negative branch
offsets, broader immediate ALU execution, and longer mixed programs.
The directed assembly files in `sim/programs/` are starting points; an
automated assembly and result-checking pipeline is still needed. Architectural
tests and physical FPGA validation are separate milestones.

## Expanded execution checks

`test_execution.py` generates independent instruction words and expected
retirements for `tb_program.vhd`. All 13 programs check PC, instruction, write
enable, destination, and result; traps check cause, PC, tval, absence of later
retirement/requests, and reset recovery. Data requests go through the real bus.

Coverage includes every load/store width; all four byte lanes and both halfword
lanes; signed/unsigned extension; preservation of unselected store lanes;
loads and writes to x0; all ten register ALU operations at boundary values;
shift amounts 0, 1, 31 and register masking at 32; AUIPC; FENCE; each branch
condition taken and untaken (including unused misaligned targets); successful
JALR masking/link writeback; misaligned halfword/word accesses; faulting loads
to x0; ROM writes; unsupported GPIO widths and read-only GPIO stores.
The existing execution bench additionally covers JAL, ECALL, EBREAK, illegal
instructions, fetch faults, and misaligned jump/taken-branch targets.

Run `make test-adapter` for the LLVM-assembled local architectural adapter
self-test. It checks the success, failure, trap, and timeout paths; no upstream
certification tests have run. See [adapter status](arch-test/README.md).
