# DE10-Lite Bring-Up

## Status and prerequisites

The repository includes a DE10-Lite smoke wrapper, pin and timing constraints,
a board testbench, and Quartus project/build/programming scripts. The compiled
image exercises the board I/O; CPU execution is not implemented yet. See
[validation results](#validation-results) for completed checks.

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
| [`rtl/board/de10_lite_top.vhd`](../rtl/board/de10_lite_top.vhd) | 50 MHz smoke counter, synchronized switches, active-low button reset |
| [`rtl/board/reset_synchronizer.vhd`](../rtl/board/reset_synchronizer.vhd) | Asynchronous assertion, two-stage release, Quartus synchronizer attributes |
| [`constraints/de10_lite_pins.tcl`](../constraints/de10_lite_pins.tcl) | All 23 top-level pin locations, I/O standards, and explicit LED drive strength |
| [`constraints/de10_lite.sdc`](../constraints/de10_lite.sdc) | Clock, uncertainty, and asynchronous external-I/O timing exceptions |
| [`scripts/create_project.tcl`](../scripts/create_project.tcl) | Generated MAX 10 project, source list, and VHDL-2008 settings |
| [`scripts/build.tcl`](../scripts/build.tcl) | Quartus compilation, report collection, and timing validation |
| [`scripts/check_timing.tcl`](../scripts/check_timing.tcl) | Multi-corner timing, constraint checks, and unconstrained-path checks |
| [`scripts/program.tcl`](../scripts/program.tcl) | USB-Blaster JTAG configuration with a `.sof` |
| [`sim/tb_de10_lite_top.vhd`](../sim/tb_de10_lite_top.vhd) | Reset, switch, unused-input, and heartbeat checks |

The original board-specific files have been replaced. Board-independent CPU,
memory, and GPIO modules retain their interfaces. Connecting GPIO to this
wrapper is part of the later CPU integration described in the
[architecture contract](architecture.md#de10-lite-gpio-integration).

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
smoke design uses synchronous internal reset consumption, so no recovery or
removal paths remain after the external button exception. The reports state
that explicitly rather than claiming those path types were exercised.

The generated project keeps unused FPGA pins as tri-stated inputs. The smoke
build does not instantiate CPU memories; review memory inference and utilization
again after CPU integration.

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

## Smoke acceptance criteria

- `LEDR(8 downto 0)` mirrors synchronized `SW(8 downto 0)`.
- `LEDR(9)` is a heartbeat. Using counter bit 24 at 50 MHz gives approximately
  1.49 Hz (a full on/off period of about 0.67 seconds).
- Holding `KEY(0)` clears all LEDs and the heartbeat counter.
- Releasing `KEY(0)` deasserts internal reset through two clocked stages;
  sequential smoke logic resumes on a following active edge.
- The board simulation checks reset assertion between clock edges, synchronized
  release, switch propagation, unused controls, and heartbeat behavior.
  `HEARTBEAT_BIT` defaults to 24 in hardware and is set to 2 in simulation.

`SW(9)` and `KEY(1)` are unused in the smoke design. In the later CPU integration, all ten
switches are readable and all ten LEDs reflect the software LED register.

## Validation results

Validated on 2026-09-12 with GHDL and Quartus Prime Lite 25.1std.0
(build 1129), targeting `10M50DAF484C7G`:

| Check | Result |
| --- | --- |
| GHDL | All five active testbenches pass, including 270,612 decoder cases; board test completes at 471 ns |
| Full Quartus compilation | Successful; `.sof` generated |
| Worst setup slack across analyzed corners | +16.652 ns |
| Worst hold slack across analyzed corners | +0.164 ns |
| Constraint checks / unconstrained paths | Zero issues / zero unconstrained paths |
| Synchronizers | Ten recognized chains, each with two registers |
| Smoke resource usage | 48 logic elements, 45 registers, 23 pins; no RAM or PLLs |
| Physical board programming | Unverified; the hardware scan detected no JTAG hardware |

The Quartus smoke-build results above were recorded during the board port.
The decoder was completed afterward and is covered by the GHDL suite; it is
not instantiated in the standalone smoke top.

The compile emits expected warnings for unused `KEY(1)` / `SW(9)`, the Lite
edition's unavailable LogicLock feature, and MAX 10's general 3.3 V input
interface requirements. Pin locations, I/O standards, and LED drive strengths
are explicitly assigned; the incomplete-I/O-assignment warning has been resolved.
These results validate the smoke design, not the unfinished processor.

## CPU bring-up

1. Pass the unit, memory-bus, core retirement, and trap simulations.
2. Generate a program image that writes `0x0000_0155` to `0x4000_0000` and loops.
3. Connect the core, memory bus, and board I/O according to the
   [architecture contract](architecture.md); rebuild and program the `.sof`.
4. Confirm that the low ten LED bits show the programmed value, and that reset
   restarts execution at `0x0000_0000`.
5. Exercise switch reads, RAM byte lanes, and branch loops before larger software.
6. Observe traps and retirement with simulation or Signal Tap. Define any future
   seven-segment or LED debug mode before it overrides software-visible outputs.
7. Archive the Quartus version, source revision, program image, device selection,
   utilization report, and timing results with the hardware test result.
