# DE10-Lite Bring-Up

The active design uses JTAG UART and a ROM program loader. Read the
[console/upload guide](uart.md) before hardware testing. Current simulation
results are in the [JTAG verification record](validation/2026-10-14-jtag/README.md).
Intel IP generation, Quartus fitting/timing, and physical board validation are pending.

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
JTAG clock/CDC constraints; inspect their application in the generated reports.
Do not add broad internal false paths to silence JTAG timing failures.

## Configure through JTAG

```sh
quartus_pgm --list
make program
# Or select the exact cable name reported above:
make program CABLE='USB-Blaster [1-1]'
```

Run `make build` successfully first: `make program` does not rebuild. A .sof
from either earlier GPIO or physical-UART design cannot provide this loader.
Programming is volatile; persistent .pof flash programming remains a separate
step. Close JTAG terminals during programming.

## Hardware acceptance

1. Program the fresh .sof, install host support and open the JTAG console.
2. Press KEY(0); observe `RV32I JTAG loader v1` and `ready> `.
3. Close the console and upload/run `software/build/hello.bin` using the helper.
4. Confirm the hello message, `EXIT 0000002A`, and the next prompt.
5. Run the same program again, then change/rebuild/upload it without rebuilding FPGA hardware.
6. Check bad-image rejection and reset recovery. KEY(0) requires a fresh upload.
7. Archive Quartus/IP versions, source/ROM/application hashes, fit, timing,
   cable/device/instance selection, and physical test outcome.

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
