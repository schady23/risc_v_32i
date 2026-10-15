# UART migration verification - October 14, 2026

The active board design now uses UART instead of LED/switch GPIO. This record
describes local simulation/software checks, not a programmed-board test.

| Check | Result |
| --- | --- |
| ROM build | GCC 12.2.0, `-march=rv32i -mabi=ilp32`, 159-byte image, entry at zero |
| GHDL | 6.0.0, mcode Windows backend; eight fixed benches and 13 directed programs passed |
| Decoder | 270,612 cases passed |
| UART peripheral | Full duplex, TX framing/order, RX FIFO overflow/wrap, simultaneous full-FIFO pop/push, W1C/error priority, invalid accesses, false start, bad stop/break, baud tolerance, reset passed |
| Board integration | Actual 50 MHz/115200 settings: ROM banner, six binary/CRLF echoes, button reset/restart passed |
| Architectural adapter | GNU-assembled local pass/fail/trap/timeout self-tests passed; no upstream certification run |
| GHDL synthesis | UART and integrated `de10_lite_top` accepted; ROM, byte-bank RAM, and 16x8 RX FIFO recognized |
| Host helper | CLI/port listing and 22-byte `loop://` self-test passed; this is a software loopback |
| Diagram | Three pages regenerated for UART, rendered and visually inspected |
| Quartus / hardware | Not run: Quartus unavailable in this environment; no serial adapter detected |

ROM binary SHA256:

```text
e4fa2c8326ae4980903cdbde7ed5928c9802beb4377d447cf01b840621dc953a
```

The simulation transcript is in [simulation.txt](simulation.txt).
The integrated synthesis diagnostic transcript is in [synthesis.txt](synthesis.txt).
GHDL reports time-zero `numeric_std` metavalue warnings from initial settling
and ignores Quartus-specific preservation/synchronizer/RAM-style attributes.
These warnings do not fail the checks. Quartus must still verify those
attributes, memory mapping, device fit, and 50 MHz timing.

Reproduction (with tools on PATH):

```sh
python scripts/build_software.py --prefix riscv64-unknown-elf-
python scripts/simulate.py
# Export RISCV_PREFIX for GNU, or use the adapter runner's default LLVM tools.
python scripts/test_arch_adapter.py
ghdl --synth --std=08 --workdir=build/ghdl de10_lite_top
python scripts/uart_terminal.py --port loop:// --test
```

For physical bring-up, run a **new** `make build`, program the resulting `.sof`,
wire a 3.3 V UART adapter, and follow [UART setup](../../uart.md).
September 30 utilization/timing/SOF evidence applies to the earlier GPIO design.
