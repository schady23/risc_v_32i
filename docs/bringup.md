# DE10-Lite Bring-Up

## Status and prerequisites

The repository includes an integrated DE10-Lite CPU wrapper, pin and timing
constraints, a board testbench, and Quartus project/build/programming scripts.
The checked-in ROM demo writes `0x155` to the LED register and loops. The CPU
system passes GHDL simulation and a full Quartus build with timing checks.
Physical board operation remains unverified. See [validation results](#validation-results).

Required tools and hardware:

- Terasic DE10-Lite and a USB cable for its onboard USB-Blaster.
- Quartus Prime Lite or Standard with MAX 10 device support and USB-Blaster
  drivers/access configured for the host OS. Check the
  [supported editions](https://www.intel.com/content/www/us/en/products/details/fpga/development-tools/quartus-prime/resource.html).
- GHDL with VHDL-2008 support for the [existing simulations](../sim/README.md).
- GNU Make, Python 3, and a bare-metal RISC-V toolchain for software images.

## Board interface

The following hardware details come from Terasic's DE10-Lite User Manual,
sections 3.2–3.4. Get the manual and System Builder from
[Terasic's resources page](https://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&No=1021&PartNo=4);
a [Terasic manual mirror](https://e2e.ti.com/cfs-file/__key/communityserver-discussions-components-files/73/DE10_2D00_Lite_5F00_User_5F00_Manual.pdf)
is also available.

| Resource | Board signal / device | Project use |
| --- | --- | --- |
| FPGA | MAX 10 `10M50DAF484C7G` | Select this device in Quartus |
| Clock | `MAX10_CLK1_50`, `PIN_P11`, 50 MHz | Single system clock, 20 ns period |
| Reset button | `KEY(0)`, `PIN_B8`, active low | Invert before the active-high reset synchronizer |
| Other button | `KEY(1)`, `PIN_A7` | Unused initially |
| Switches | `SW(9 downto 0)` | Synchronize before use |
| LEDs | `LEDR(9 downto 0)`, active high | Smoke test and CPU GPIO output |
| Seven-segment displays | Six displays, active-low segments | Optional later debugging |

Use Terasic's pin assignments and I/O standards for the exact board revision.
The manual specifies 3.3-V LVTTL for the clock, switches, and LEDs, and the
3.3 V Schmitt Trigger input standard for the buttons. Keep unused peripherals
out of the initial top-level interface; configure unused pins appropriately.

## Board-support files

| File | Responsibility |
| --- | --- |
| [`rtl/board/de10_lite_top.vhd`](../rtl/board/de10_lite_top.vhd) | 50 MHz CPU, memory bus, GPIO LEDs, and active-low button reset |
| [`rtl/board/reset_synchronizer.vhd`](../rtl/board/reset_synchronizer.vhd) | Asynchronous assertion, two-stage release, Quartus synchronizer attributes |
| [`constraints/de10_lite_pins.tcl`](../constraints/de10_lite_pins.tcl) | All 23 top-level pin locations, I/O standards, and explicit LED drive strength |
| [`constraints/de10_lite.sdc`](../constraints/de10_lite.sdc) | Clock, uncertainty, and asynchronous external-I/O timing exceptions |
| [`scripts/create_project.tcl`](../scripts/create_project.tcl) | Generated MAX 10 project, source list, and VHDL-2008 settings |
| [`scripts/build.tcl`](../scripts/build.tcl) | Quartus compilation, report collection, and timing validation |
| [`scripts/check_timing.tcl`](../scripts/check_timing.tcl) | Multi-corner timing, constraint checks, and unconstrained-path checks |
| [`scripts/program.tcl`](../scripts/program.tcl) | USB-Blaster JTAG configuration with a `.sof` |
| [`sim/tb_de10_lite_top.vhd`](../sim/tb_de10_lite_top.vhd) | LED software demo, button reset, and restart checks |

The CPU, memory bus, and GPIO are connected in the wrapper according to the
[architecture contract](architecture.md#de10-lite-gpio-integration). The GPIO
module synchronizes all ten switch inputs before software reads them.

## Create and compile the Quartus project

From the repository root, with Quartus tools on `PATH`:

```sh
make test
make build
```

`make build` regenerates the project from tracked sources, runs Analysis &
Synthesis, Fitter, Assembler, and Timing Analyzer, then performs explicit timing
checks. Generated project edits are overwritten on the next build; change the
tracked Tcl/SDC files to make persistent settings changes.

| Output | Path |
| --- | --- |
| Quartus project | `build/quartus/risc_v_32i.qpf` |
| Programming image | `build/quartus/output_files/risc_v_32i.sof` |
| Full compiler and Fitter reports | `build/quartus/output_files/` |
| Timing summary | `build/reports/timing_summary.rpt` |
| Utilization summary | `build/reports/utilization.rpt` |
| Constraint checks | `build/reports/constraint_checks.rpt` |
| Unconstrained paths | `build/reports/unconstrained_paths.rpt` |
| Synchronizer report | `build/reports/metastability.rpt` |

Use `make project` to generate only the project or `make timing` to recheck an
existing compilation. Equivalent direct commands are:

```sh
quartus_sh -t scripts/create_project.tcl
quartus_sh -t scripts/build.tcl
quartus_sta -t scripts/check_timing.tcl
```

The SDC defines a 20 ns clock and derives clock uncertainty. Switch/button
inputs are asynchronous, and LEDs have no external capture clock, so their
external paths are explicitly excepted. Register-to-register paths, including
synchronizer settling paths, remain timed. Revisit these exceptions if the
external interface changes.

The timing script checks setup, hold, recovery, and removal paths at all
operating corners returned for the selected device. It rejects negative slack,
missing setup paths, constraint issues, and unconstrained paths. The current
CPU design uses synchronous internal reset consumption, so no recovery or
removal paths remain after the external button exception. The reports state
that explicitly rather than claiming those path types were exercised.

The generated project keeps unused FPGA pins as tri-stated inputs. The CPU build uses 16 M9Ks for RAM and four for the optimized two-port ROM.
Recheck inference and capacity whenever the program image or memory design changes.

## Configure the board through JTAG

After a successful compile, connect the board and list available cables:

```sh
quartus_pgm --list
```

Select the DE10-Lite's USB-Blaster. With one USB-Blaster connected:

```sh
make program
```

If several cables are connected, provide the exact cable name from the list:

```sh
make program CABLE='USB-Blaster [1-1]'
```

The example cable name is a placeholder; use the actual name reported on your
machine. The script targets the first JTAG device, as on a standalone DE10-Lite.
`make program` uses the existing `.sof` and does not rebuild it; run `make build`
successfully after any RTL, constraint, or program-image change before programming.

To use the GUI instead:

1. Connect and power the DE10-Lite using its documented USB setup.
2. Open Quartus Programmer, select the onboard USB-Blaster in Hardware Setup,
   and select JTAG mode.
3. Detect the device chain and confirm the MAX 10 target.
4. Add the generated `.sof`, enable Program/Configure, and start configuration.
5. Confirm completion, then check the smoke behavior below.

A `.sof` configures volatile FPGA configuration RAM. Persistent boot requires a
separate MAX 10 internal-flash programming flow, commonly using a `.pof`; defer
that until the smoke and CPU builds work. See the
[MAX 10 configuration guide](https://docs.altera.com/r/docs/683865/current/max-10-fpga-configuration-user-guide/configuring-max-10-devices-using-jtag-configuration?contentId=8xFe_De5VEDzB~BeH3M5cA)
for JTAG configuration details.

## CPU demo acceptance criteria

- After reset release, the checked-in ROM program writes `0x155` to the LED
  register. `LEDR(9 downto 0)` displays `0101010101` and stays at that value.
- Holding `KEY(0)` clears all LEDs. Releasing it restarts execution at address
  zero and restores the same LED pattern.
- `SW(9 downto 0)` is available to software through the switch register.
  `KEY(1)` remains unused.
- The board simulation checks LED output, reset, and program restart. Physical
  button, LED, and switch behavior still needs board verification.

## Validation results

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

## CPU bring-up

1. Run the fixed benches and directed programs with `make test`.
2. Rebuild the connected CPU system in Quartus and inspect memory inference,
   utilization, and timing reports.
3. Program the resulting `.sof` and check the LED demo on the board.
4. Confirm that the low ten LED bits show the programmed value, and that reset
   restarts execution at `0x0000_0000`.
5. Exercise switch reads, RAM byte lanes, and branch loops before larger software.
6. Observe traps and retirement with simulation or Signal Tap. Define any future
   seven-segment or LED debug mode before it overrides software-visible outputs.
7. Archive the Quartus version, source revision, program image, device selection,
   utilization report, and timing results with the hardware test result.
