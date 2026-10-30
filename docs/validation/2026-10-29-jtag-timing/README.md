# JTAG timing correction October 29 2026

The current JTAG loader design passes a full Quartus Prime Lite 25.1std.0
build and the explicit timing checker for MAX 10 `10M50DAF484C7G`. The design
has zero unconstrained clocks, ports, or paths under the external timing
assumptions below. The SOF is ready for physical board acceptance.

## Correction

The earlier user compilation succeeded, but `make timing` found two inputs
(`altera_reserved_tdi`, `altera_reserved_tms`) and one output
(`altera_reserved_tdo`) without I/O delay constraints. They accounted for
41 input paths and one output path. All previously analyzed paths had positive
slack, but this missing coverage prevented timing sign-off.

`constraints/de10_lite.sdc` now specifies both minimum and maximum delays.
The setup budget follows
[Intel's 3 ns JTAG reference example](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-cyclone-10-lp-fpga-kit-build-a-custom-hardware-system.html).
TDI and TMS use -3 to +3 ns relative to falling TCK. TDO uses +3 ns maximum
output delay and -3 ns minimum delay relative to rising TCK, requiring 3 ns
of external setup and hold. The minimum bounds make hold/skew assumptions
explicit and are stricter than the example's implicit +3 ns minimum.

These are design budgets for the DE10-Lite's on-board USB-Blaster, not measured
board or cable delays. The existing Intel-generated 10 MHz TCK target and
50 MHz CPU clock remain in place. No new false-path exceptions were added.
Physical upload/run/reset acceptance is still needed; changing the cable,
JTAG chain, or clock requires reviewing these external assumptions.

The checker now distinguishes negative slack from missing/invalid constraints
and prints each failing constraint row once with its setup and hold counts.
Either failure still produces a nonzero exit status.

## Validation

An initial `make timing` rerun passed on the user's fitted design. Then
`make build` regenerated the Intel IP, compiled the complete system using the
corrected SDC, generated a fresh SOF, and passed the timing checker again.
See the [full build log](build.txt).

| Check | Worst slack across operating corners |
| --- | --- |
| Setup | +2.339 ns |
| Hold | +0.096 ns |
| Recovery | +16.793 ns |
| Removal | +0.403 ns |

All three available operating corners passed. The constraint checks report
zero missing/multiple clocks, loops, latches, or clock-uncertainty issues.
The unconstrained-path report has zero counts in all setup and hold columns.

Evidence: [timing summary](timing-summary.txt),
[constraint checks](constraint-checks.txt),
[unconstrained paths](unconstrained-paths.txt), and [clocks](clocks.txt).

The fit uses 3,336 logic elements (7%), 1,504 registers, and 394,240 memory
bits (24%). See the [utilization summary](utilization.txt). Full compilation
reported zero errors and 17 warnings. Remaining warnings concern the unused
KEY(1), vendor connectivity/default JTAG constraint filters, Lite-edition
LogicLock availability, and MAX 10 voltage-interface requirements. Timing
analysis still reports six vendor empty-filter/empty-collection warnings;
they have not been suppressed.

Temporary checker failure tests removed JTAG I/O delays and separately
requested a 1 ns CPU clock period in memory. The first correctly failed with
the incomplete-constraints message and four distinct failure rows. The second
correctly failed with the negative-slack message and no constraint failures.
Their reports were isolated under `build/timing-check-tests`; the project SDC,
programming file, and successful `build/reports` results were unchanged.
See the [failure-test summary](checker-tests.txt).

## Programming file

Use `build/quartus/output_files/risc_v_32i.sof` from this build. SHA256:

```text
9d47f4ddc5c03f823a16a764951a4dadb9ad7cc92df3df66133d5b12743686fd
```

The corrected SDC SHA256 is:

```text
31e6b6d9d16c7f0ff10466900539f554a3adcb3fa2aa4ccd6027463fd44f502f
```

The next step is programming and testing hello and mixed_ram, including return
to the loader, rerun, and KEY(0) recovery. Save the board photo and console logs
with the SOF identity above. No board was programmed during this correction.
