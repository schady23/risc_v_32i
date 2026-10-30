# DE10-Lite Bring-Up

The active design uses JTAG UART and a ROM program loader. Read the
[console/upload guide](uart.md) before hardware testing. Current simulation
results are in the [JTAG verification record](validation/2026-10-14-jtag/README.md).
Intel IP generation, full compilation, and timing checks are validated with
Quartus Prime Lite 25.1 on October 29. Physical upload, execution and rerun of
both example applications are documented in the [board evidence](validation/2026-10-29-board/README.md).
Recorded reset and error-recovery acceptance remains pending.
See the [preparation record](validation/2026-10-29-quartus-prep/README.md) and
[JTAG timing results](validation/2026-10-29-jtag-timing/README.md).

## Hardware and tools

- DE10-Lite with its existing USB-Blaster connection and driver.
- Quartus Prime Lite/Standard with MAX 10 and Platform Designer support.
- GHDL and Python 3 for local checks.
- Bare-metal RISC-V GCC/objcopy for rebuilding the loader or applications.
- Python host binding and the native Quartus JTAG libraries for upload/console.

No serial adapter or jumper wiring is needed. JTAG uses dedicated device pins;
the top level exposes only the 50 MHz P11 clock and KEY[0:1] buttons B8/A7.
The clock uses 3.3-V LVTTL and buttons use 3.3 V Schmitt Trigger. KEY(1) is unused.
The board keeps unused pins tri-stated. The former UART V10/W10 assignments
are removed.

## Build the ROM and application

```sh
make image
make app
make test
```

Without Make, use `python scripts/build_software.py`,
`python scripts/build_app.py software/hello.S --test-image sim/images/hello.hex`,
`python scripts/simulate.py`, and `python scripts/test_jtag_console.py`.
Use `--prefix` or exported `RISCV_PREFIX` for a different toolchain directory.
This installation includes a suitable compiler under Quartus's RiscFree tools:

```sh
make image app RISCV_PREFIX=/opt/intelFPGA/25.1/riscfree/toolchain/riscv32-unknown-elf/bin/riscv32-unknown-elf-
```

## Generate Intel IP and compile the FPGA

```sh
make build
# Equivalent:
quartus_sh -t scripts/build.tcl
```

`create_project.tcl` invokes `generate_jtag_ip.tcl`, which locates the installed
qsys-script/qsys-generate tools. `create_jtag_uart.tcl` creates a matching-version
Intel `altera_avalon_jtag_uart` component with 64-byte RX/TX FIFOs, exported
clock/reset and Avalon interfaces. The generated QIP is added to the project.
The IP is generated locally, not checked in or replaced by the GHDL model.
Generation failure or a missing QIP stops the build.
An explicit 50 MHz direct clock bridge supplies the IP's frequency metadata;
it does not add a PLL or divider. The unconnected interrupt warning is expected
because the CPU polls the JTAG UART.

For compilation in the Quartus GUI:

1. Run `make project` to generate the Intel IP and current project settings.
2. Open `build/quartus/risc_v_32i.qpf` in Quartus.
3. Select **Processing > Start Compilation** and wait for a successful full build.
4. From the repository root, run `make timing` for the explicit timing checks.
5. Program the newly generated `build/quartus/output_files/risc_v_32i.sof`.

Project generation saves existing settings as `risc_v_32i.qsf.bak` before
writing a fresh QSF. Make persistent edits in `scripts/create_project.tcl` or
the tracked constraints, since regeneration replaces generated assignments.
Existing programming files and fit/timing reports can predate this design;
verify the new compilation's timestamp before programming or reporting results.

The system wrapper instantiates generated `jtag_uart_system` with `clk_clk`,
`reset_reset_n`, `av_address`, `av_chipselect`, `av_read_n`, `av_write_n`,
`av_writedata`, `av_readdata`, and `av_waitrequest`. IRQ is not exported or used.
Check generated ports when changing Quartus versions.

| Output | Path |
| --- | --- |
| Platform Designer system | `build/ip/jtag_uart_system.qsys` |
| Generated IP QIP | `build/ip/jtag_uart_system/synthesis/jtag_uart_system.qip` |
| Quartus project | `build/quartus/risc_v_32i.qpf` |
| Programming file | `build/quartus/output_files/risc_v_32i.sof` |
| Utilization/timing reports | `build/reports/` |

The build compiles the system and explicitly checks setup/hold/recovery/removal
across available operating corners, constraint issues, and unconstrained paths.
The board SDC defines 50 MHz and asynchronous KEY inputs. The Intel IP supplies
the 10 MHz JTAG clock target and internal CDC constraints. The board SDC adds
explicit input and output delays for the dedicated JTAG pins. Following
[Intel's reference example](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-cyclone-10-lp-fpga-kit-build-a-custom-hardware-system.html),
the external setup budget is 3 ns. Inputs allow -3 to +3 ns relative to falling
TCK, and TDO has 3 ns setup and hold budgets relative to rising TCK. These
are timing assumptions for the on-board USB-Blaster, rather than measured
board/cable delays. Hardware acceptance remains necessary.
Do not add broad internal false paths to silence JTAG timing failures.

`make timing` reports missing/invalid constraints separately from negative
timing margins. Each failing constraint row is printed once, with separate
setup and hold counts, and either type of failure returns a nonzero status.

## Configure through JTAG

```sh
quartus_pgm --list
make program
# Or select the exact cable name reported above:
make program CABLE='USB-Blaster [1-1]'
```

Complete `make build`, or GUI compilation followed by `make timing`, first:
`make program` does not rebuild. A .sof
from either earlier GPIO or physical-UART design cannot provide this loader.
Programming is volatile; persistent .pof flash programming remains a separate
step. Close JTAG terminals during programming.

## Hardware acceptance

1. Program the fresh .sof, install host support and open the JTAG console.
2. Press KEY(0); observe `RV32I JTAG loader v1` and `ready> `.
3. Close the console and upload/run `software/build/hello.bin` using the helper.
4. Confirm the hello message, `EXIT 0000002A`, and the next prompt.
5. Run the same program again, then change/rebuild/upload it without rebuilding FPGA hardware.
   The second example is `software/build/mixed_ram.bin`; it must print
   `Mixed RAM loop passed: 1 3 6 10 15`, `EXIT 0000000F`, and `ready>`.
6. Check bad-image rejection and reset recovery. KEY(0) requires a fresh upload.
7. Archive Quartus/IP versions, source/ROM/application hashes, fit, timing,
   cable/device/instance selection, and physical test outcome.

After the successful current compilation and `make timing`, record the tool
version and programming-file identity for the progress report:

```sh
quartus_sh --version > build/reports/quartus-version.txt
sha256sum build/quartus/output_files/risc_v_32i.sof > build/reports/sof.sha256
```

Keep the current compilation's fit summary and detailed reports with the
timing reports, board photo, and console logs for both applications.

## Historical validation: GPIO design, September 30


**The following archived results predate UART and do not validate the current
UART build.** They are retained as evidence for the earlier CPU/RAM integration.


The integrated CPU system was validated on September 30, 2026 with Quartus
Prime Lite 25.1std.0 (build 1129), targeting `10M50DAF484C7G` at 50 MHz.
[Archived evidence](validation/2026-09-30/build.txt) records the build and SOF
hash; simulation, utilization, timing, constraints, and JTAG results are in the
same directory.

| Check | Result |
| --- | --- |
| GHDL | Seven fixed benches and 13 directed execution programs passed |
| Decoder | 270,612 cases passed |
| Local architectural adapter | Pass, explicit fail, trap, and timeout paths checked; no upstream suite run |
| Full Quartus compilation | Successful; fresh `.sof` generated |
| Worst setup slack across three corners | +4.803 ns |
| Worst hold slack across three corners | +0.150 ns |
| Constraint checks / unconstrained paths | Zero issues / zero unconstrained paths |
| Recovery / removal | No applicable paths after external button exception |
| Synchronizers | Eleven recognized chains; shortest length two registers |
| Resource use | 985 logic elements, 490 registers, 23 pins, 155,648 memory bits, 20 M9Ks |
| Physical board | No JTAG hardware available; LED/reset behavior unverified |

The initial RAM implementation expanded into 131,072 flip-flops and exceeded
the device capacity. `ram_byte_bank.vhd` now isolates the Quartus Standard
single-port inference template; four 4096x8 banks implement byte enables using
16 M9Ks. The sparse demo ROM is optimized into two 4096x3 inferred ROMs using
four additional M9Ks; its logical address space remains 16 KiB. This is
image-dependent utilization, not a guarantee for every future image.

Initialized MAX 10 memories also require an initialization-capable configuration
mode. The generated project sets `INTERNAL_FLASH_UPDATE_MODE` to
`SINGLE IMAGE WITH ERAM`; this resolves assembler error 14703. See the
[Intel MAX 10 memory guide](https://www.intel.com/programmable/technical-pdfs/683431.pdf)
for the configuration requirement. Programming still uses the volatile `.sof`;
no persistent flash programming was performed.

The remaining compile warnings concern unused `KEY(1)`, the Lite edition's
unavailable LogicLock feature, and MAX 10's general 3.3 V input requirements.
Pin locations, standards, and LED drive strengths are assigned. GPIO switch
synchronizers have explicit preservation/identification attributes.
