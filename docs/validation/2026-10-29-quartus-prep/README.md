# Quartus preparation October 29 2026

The Quartus availability blocker recorded in Report 6 on October 23 is cleared
in this environment. Quartus Prime Lite 25.1std.0 build 1129 is available at
`/opt/intelFPGA/25.1/quartus`. Current Intel JTAG UART IP generation and Quartus
analysis/elaboration passed during this initial preparation. A
[later timing correction and full build](../2026-10-29-jtag-timing/README.md)
completed fitting/timing checks and produced a fresh SOF. Physical board
testing remains pending.

## Changes and verified preparation

- Replaced unsupported `file normalize` in the Platform Designer script with
  path operations supported by its Tcl interpreter.
- Added a direct 50 MHz clock bridge so the generated JTAG UART receives the
  correct clock-frequency metadata. The generated top-level ports still match
  `rtl/board/de10_lite_top.vhd`; no board RTL or pin change was required.
- Fixed project regeneration retaining obsolete GPIO assignments. Existing
  generated QSF settings are moved to `.qsf.bak` before creating fresh settings.
  The regenerated project contains the current CPU/system/JTAG sources and
  only the clock and KEY pin assignments.
- Rebuilt the 906-byte ROM loader with the installed RiscFree RISC-V GCC 13.2.0.
  The resulting checked-in ROM image differs from the older compiler's image.
- Built `hello.bin` (328 bytes) and the new `mixed_ram.bin` (425 bytes, padded
  to 428 bytes for upload). Both link at the application entry `0x10000`.
- `make test` passes all 11 fixed benches, an additional integration run for
  mixed_ram, all 14 directed programs, and all five host-protocol tests.
  Existing time-zero `numeric_std` settling warnings remain.

The second application computes and stores 1, 3, 6, 10, and 15, reloads each
store, and independently compares all final RAM words against fixed constants.
It prints `Mixed RAM loop passed: 1 3 6 10 15` and returns 15 only after the
checks pass. Its integration run finishes at 10731890 ns and verifies three
executions across a rerun and replacement upload, CRC rejection, return to the
loader, and reset during an upload. The hello integration run finishes at
8409710 ns and retains its initialized-data/BSS checks.

## Quartus checks

`make project` successfully generated Intel `altera_avalon_jtag_uart` 25.1
with 64-byte RX and TX FIFOs. The unconnected interrupt warning is expected
because the CPU uses polling. See the [generation log](ip-generation.txt).

From `build/quartus`, `quartus_map risc_v_32i --analysis_and_elaboration`
completed with zero errors and one connectivity-summary warning. The detailed
report locates the warning in the vendor `alt_jtag_atlantic` instance's unused
legacy JTAG ports; the generated IP uses the automatically generated SLD fabric.
This stage does not establish fitting, timing closure, or physical operation.
See the [command log](analysis-elaboration.txt) and
[analysis report](analysis-report.txt).

## Next hardware run

1. Open `build/quartus/risc_v_32i.qpf` and select **Processing > Start Compilation**.
2. After successful compilation, run `make timing` from the repository root.
3. Review current fit/memory use, constraints, and setup/hold/recovery/removal
   results. Record the new SOF's SHA256 and tool versions.
4. Program the new SOF and test hello, rerun, and KEY(0) recovery. Reset requires
   a fresh upload.
5. Upload mixed_ram without rebuilding the FPGA. Expect the success message,
   `EXIT 0000000F`, and `ready>`, including on a second run.
6. Save the console logs and board photo tied to the new SOF hash.

At the end of initial preparation, the existing
`build/quartus/output_files/risc_v_32i.sof` was still the September GPIO build;
project generation and analysis/elaboration did not replace it. The later full
build linked above replaced it and records the new SOF hash.

The [bring-up guide](../../bringup.md) provides the GUI and timing workflow;
the [upload guide](../../uart.md) provides both application procedures.
Report 6 and its October 23 evidence retain their historical results.

## Software identities

SHA256 values from this preparation:

```text
e78098645f036cc403e36492dda63036532fb1e303eebece653879095b3f053e  rtl/memory/program_image_pkg.vhd
078748a1054008c1ac54f73c2050f9a0a20023e93231340763ed79dd81550f78  software/build/loader.bin
74f6b01622bb7e177c85fe9fca7c1c7c317431bceb0c4e3776f664253c9f3979  software/build/hello.bin
5f58bd76408e3dbe330c311f4506acd7791e2eca7b17998bb1e0bf3b8b70a3a8  software/build/mixed_ram.bin
69d369c44a9d113d338ae9511b5e93b30bc2cdef51fe5beaa67e9d616e3833ef  sim/images/mixed_ram.hex
```

Rebuild software with:

```sh
make image app RISCV_PREFIX=/opt/intelFPGA/25.1/riscfree/toolchain/riscv32-unknown-elf/bin/riscv32-unknown-elf-
make test
make project
```
