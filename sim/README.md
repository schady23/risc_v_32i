# Simulation and Testbenches

`sim/` is this project's testbench directory. The RTL and tests use VHDL-2008;
the DE10-Lite board test uses the same 50 MHz clock as the hardware.

## Current coverage

| Testbench | What it checks today |
| --- | --- |
| `tb_alu.vhd` | ADD, SUB wraparound, signed/unsigned SLT, and SRA examples |
| `tb_decoder.vhd` | All 40 RV32I mnemonics, immediate/control decoding, reserved encodings, register fields, and unknown inputs |
| `tb_regfile.vhd` | One register write/read and rejection of writes to `x0` |
| `tb_memory_bus.vhd` | An unmapped data access faults for one response cycle |
| `tb_de10_lite_top.vhd` | Startup/button reset, synchronized release and switches, spare inputs, heartbeat period and restart |
| `tb_core.vhd` | Empty placeholder; does not test instruction execution |

Passing these unit tests does not establish full CPU execution correctness or
physical board operation. The core execution harness is still a placeholder.

## Run the existing tests

Prerequisites: GHDL with VHDL-2008 support, GNU Make, Bash, and the `timeout`
utility. From the repository root:

```sh
make test
```

This invokes [`scripts/simulate.sh`](../scripts/simulate.sh), which contains the
ordered source list, analyzes all RTL/testbench files, and runs each active
bench with assertion failures enabled and a 30-second wall-clock timeout.
Compilation products go under ignored `build/ghdl/`. A failed assertion,
compilation error, or timeout produces a nonzero exit status. Set `GHDL` to
select another GHDL executable, for example `make test GHDL=/path/to/ghdl`.

Each of the five active benches should print its own `passed` message and stop.
The core placeholder is analyzed for syntax only; it is intentionally excluded
from the execution list because it has no assertions or stimulus.

To inspect an ALU waveform after analysis:

```sh
ghdl --elab-run --std=08 --workdir=build/ghdl tb_alu \
  --assert-level=error --wave=build/ghdl/tb_alu.ghw
```

The board test sets `HEARTBEAT_BIT=2` to check complete blink cycles quickly.
The hardware default remains 24. The test uses a 20 ns clock and active-low
`KEY(0)` stimulus, including transitions between clock edges. Generic CPU and
memory unit-test clocks need not match the physical board clock.

## Decoder tests

[`tb_decoder.vhd`](tb_decoder.vhd) checks 270,612 decode cases. Every case checks
legality, the immediate, raw register fields, and the complete control record.
The RTL, shared control types, and testbench include comments explaining bit
placement, sign extension, control semantics, and the purpose of each sweep.

Coverage includes:

- Fixed machine-code examples for all 40 RV32I instructions, independently
  assembled with LLVM 22.1.8. Running the tests requires only GHDL, not LLVM.
- Every R-format funct7/funct3 combination, every immediate-ALU encoding,
  all I/S offsets, and all even B offsets under all funct3 values.
- Every shift amount and upper shift-function pattern, including rejection of
  RV64 shift amounts and unsupported extensions.
- All SYSTEM function values and funct3 combinations, plus reserved register
  fields for ECALL/EBREAK; all FENCE immediate fields and register combinations.
- Unsupported opcodes, register-address combinations, U/J boundary values,
  walking-bit patterns, and reproducible mixed U/J values.
- Legal instructions targeting `x0`, clearing stale controls after invalid
  words, and simulation-only handling of unknown/high-impedance inputs.

After `make test` has analyzed the sources, rerun just the decoder with:

```sh
ghdl --elab-run --std=08 --workdir=build/ghdl tb_decoder --assert-level=error
```

A successful run reports `tb_decoder passed: 270612 decode cases` and stops at
270,612 ns. These are decoder checks, not tests of actual ALU execution, branch
target alignment, memory faults, or retirement. Those belong in the core tests.

## Verification milestones

1. Exercise every ALU operation, shifts by 0 and 31, shift-amount masking,
   arithmetic wraparound, and signed comparison boundaries. Verify both
   register read ports, write enable, reset, and `x0` protection.
2. Use the tested decoder controls in core-level tests that check operand
   selection, branch decisions, memory accesses, and writeback together.
3. Extend bus tests to ROM/RAM boundaries, byte enables, GPIO word-only access,
   read-only targets, response timing, and stores rejected without side effects.
4. Build `tb_core` around checked retirement events and traps. Include a cycle
   timeout and require explicit completion so an inactive core cannot pass.
5. Assemble and run `programs/` with expected register/memory results. These
   files are directed-test starting points; an automated assembly/run pipeline
   and result checker have not been implemented.
6. Cover the [architecture contract](../docs/architecture.md), especially
   alignment, taken versus untaken branches, `JALR` masking, access faults,
   no retirement on traps, and reset recovery from `HALT`.
7. Integrate [architectural tests](arch-test/README.md), then extend the board
   test when the CPU replaces the standalone smoke logic. Follow the
   [board acceptance criteria](../docs/bringup.md#smoke-acceptance-criteria).

Simulation checks functional behavior. Quartus timing analysis and physical
board testing are separate acceptance steps.
