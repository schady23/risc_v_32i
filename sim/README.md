# Simulation and Testbenches

Run `make test` from the repository root with GHDL, GNU Make, Bash, and
`timeout` installed. The runner analyzes VHDL-2008 sources in order and runs
all seven active benches with assertion failures enabled. A failed assertion,
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

The current suite does not cover every RV32I execution combination. Next tests
should exercise all ALU edge cases, every load/store width and sign extension,
all branch and jump variants, reset from every core state, and longer programs.
The directed assembly files in `sim/programs/` are starting points; an
automated assembly and result-checking pipeline is still needed. Architectural
tests and physical FPGA validation are separate milestones.
