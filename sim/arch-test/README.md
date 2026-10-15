# RISC-V Architectural Test Adapter

## Current status

The multi-cycle core executes instructions. `sim/tb_program.vhd` checks directed
retirement traces; `sim/tb_arch_program.vhd` supplies a first local runner for
self-checking flat binaries. Upstream ACT4 tests have **not** been generated or
run, and no architectural certification is claimed.

The [upstream ACT4 README](https://github.com/riscv/riscv-arch-test) describes
self-checking ELFs generated using a DUT configuration, platform macros, linker
script, and Sail reference results. This local adapter is groundwork for that
flow, not a replacement for those inputs.

## Local completion contract

The adapter self-test uses LLVM by default. An exported `RISCV_PREFIX` selects
GNU GCC/objcopy instead (for example `riscv64-unknown-elf-`, optionally with an
absolute tool directory). Run `python scripts/simulate.py` first to analyze
the benches, then `python scripts/test_arch_adapter.py`.

- Code starts at zero in a 16 KiB ROM image. Data accesses use the real memory
  bus, RAM, and UART. Each simulation starts with zero-initialized RAM.
- Reserve RAM word `0x00013FFC` for completion. An accepted aligned `SW` of
  `1` passes; any other value fails. It is ordinary RAM observed by the
  simulator, not a new MMIO register. JTAG UART staging status is read-only.
- Unexpected traps, byte/halfword completion stores, bus faults, a cycle limit,
  and a 30-second wall-clock limit fail. A loop without completion cannot pass.
- `linker.ld` reserves the completion word and rejects initialized `.data`;
  implementing ROM-to-RAM initialization remains necessary for tests needing it.
- The harness loads the supplied instruction image, while data reads from ROM
  still use the built-in board image. Tests reading their own code/constants
  through the data port require shared image loading before upstream use.

After `make test` analyzes the benches:

```sh
make test-adapter
python3 scripts/run_arch_binary.py path/to/test.bin --max-cycles 100000
```

`make test-adapter` requires Clang, LLD, and llvm-objcopy. It assembles the
tracked `adapter_selftest.S` and checks pass, explicit failure, unexpected trap,
and timeout paths. The binary runner itself requires only Python and GHDL.
Flat images must be nonempty, at most 16 KiB, and linked at address zero.

## Remaining ACT4 work

Pin an upstream revision and record its tools; provide a validated RV32I UDB
configuration and `rvmodel_macros.h`; connect pass/fail macros to the RAM
completion convention; load the same image on both ROM ports and initialize
RAM data. This DUT has XLEN 32, IALIGN 32, no optional extensions or privileged
CSRs, and halts on traps. Review test requirements and document exclusions
before running any upstream suite. Record executed tests and their individual
results. Directed timing, trap, and retirement tests and physical FPGA checks
remain separate validation steps.
