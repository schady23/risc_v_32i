# Progress Report 6 results

Report 6 covers October 16 through October 22, 2026, with a verification
supplement completed October 23. The new tests were implemented and run on
October 23; they are not backdated into the reporting week.

## Report 5 review

The three completed goals in Report 5 match the archived October 12 and
October 15 evidence. Its three next-week goals were extended reset coverage,
a mixed RAM program and a current Intel JTAG UART/Quartus build. Those are the
three prior goals assessed in Report 6, rather than repeating Report 4's goals.

Report 5's state diagram had clipped memory-state labels. Its embedded image
was replaced with [a corrected rendering](report-5-state-diagram-corrected.png)
using shorter labels. A stray three-letter fragment below the title was removed
after saving the open Word document; substantive text was retained. The
original diagram and dated simulation evidence remain unchanged. Report 5's
seven pages were rendered and reviewed; Report 6's six pages were likewise
rendered and reviewed using Microsoft Word and the packaged PNG renderer.

## Goal 1 complete as of October 23

[`tb_core_reset_extended`](../../../sim/tb_core_reset_extended.vhd) uses the real
CPU, register file, memory bus and RAM with an independent six-instruction ROM.
It injects four resets on falling edges, away from rising acceptance edges:

1. Fetch request, before acceptance.
2. Fetch response, after acceptance and before the instruction is consumed.
3. Load request, before acceptance.
4. Load response, after acceptance and before the data is consumed.

All four cases suppress requests, writeback and retirement during reset;
retirement/load-commit counters remain stable. Each restart fetches PC zero.
The test seeds x8 with 0x55 before injection, then checks ADDI x9,x8,1 returns 1
after reset, demonstrating clearing rather than merely hiding write-enable.
A fresh load after recovery returns 0x55. The bench passes at 2195 ns.

Evidence: [assertions](report-6-reset-simulation.txt),
[GHW](report-6-reset.ghw), [VCD](report-6-reset.vcd),
[waveform](report-6-reset-waveform.png).
The waveform shows the two response cases; all four are in the raw traces.
Earlier store/writeback cases remain in `tb_core_reset`. Reset in every state,
physical button behavior and board timing remain outside this coverage.

## Goal 2 complete as of October 23

[`scripts/test_execution.py`](../../../scripts/test_execution.py) now includes
`mixed_ram_loop`. It sums 1 through 5 using ADD, SW, LW, pointer/counter ADDI
instructions and a backward BNE. Four branches are taken and one falls through.
Expected retirements use fixed values independently of the RTL decoder/ALU.
The existing checker verifies every PC, instruction, register write and result,
15 accepted data requests, the expected EBREAK trap and recovery from HALT.

The program checks 41 retirements and reads all five final words back as
1, 3, 6, 10 and 15. Measured stores are at 405, 745, 1085, 1425 and 1765 ns,
at addresses 0x00010000 through 0x00010010 in four-byte increments.
The complete focused run, including trap hold/recovery, ends at 2456 ns.
This program executes from the test ROM and exercises data RAM; the existing
loader integration bench separately checks execution of uploaded code from RAM.
Turning this mixed loop into an uploadable application is a new goal.

Evidence: [program image](report-6-mixed.hex),
[independent expected trace](report-6-mixed.trace),
[assertions](report-6-mixed-simulation.txt), [GHW](report-6-mixed.ghw),
[VCD](report-6-mixed.vcd), [measured stores](report-6-mixed-stores.json),
[visual results](report-6-mixed-results.png).

## Goal 3 partially complete

The actual `quartus_sh --version` [preflight](report-6-quartus-preflight.txt)
failed with Windows error 2 because the executable was unavailable in the
execution environment. Neither the normal user PATH nor checked standard
Quartus installation paths exposed the build tools. Intel IP generation,
current fit/timing and a fresh SOF remain pending. No board test was performed.
The historical September GPIO build does not validate the current JTAG design.

The October 21 user guide documents the planned workflow; its photos and
instructions do not establish that a physical CPU test was completed.

## Regression

- [GHDL regression](report-6-regression.txt): 11 fixed benches and 14 directed
  programs pass, including 270,612 exhaustive decoder cases and the real
  loader/CPU/RAM/Avalon-model integration bench.
- [Host protocol tests](report-6-host-tests.txt): five pass.
- [Local architectural adapter](report-6-adapter.txt): pass/fail/trap/timeout
  checks pass using the GNU RISC-V tools; no upstream certification suite ran.
- Existing time-zero `numeric_std` metavalue settling warnings remain.
- No RTL datapath, bus, loader firmware, memory-map or board-constraint change
  was needed for these verification additions. No new GHDL synthesis run is
  claimed for this report.

Reproduce with `python scripts/report6_evidence.py`, with GHDL, Pillow and the
adapter's compiler/objcopy available. Export `GHDL` and `RISCV_PREFIX` for
absolute tool paths if needed. The Quartus preflight is recorded but does not
fail the simulation-only evidence command. Any failing simulation, host test,
adapter check or measured-value assertion fails that command.

## Three new goals

1. **Build the current JTAG design by October 26.** Generate Intel IP, compile
   the current loader system, review fit/memory/constraints and setup/hold
   timing at 50 MHz, and archive versions, reports and SOF hash or the blocker.
2. **Test the CPU on the DE10-Lite by October 30.** After a successful build,
   program via USB-Blaster; upload/run hello.bin; check hello, EXIT 0000002A,
   return to ready>, rerun and KEY(0) recovery. Save a board photo and console
   log tied to the SOF hash. Reset requires a fresh upload.
3. **Verify a second uploaded assembly application by November 6.** Adapt the
   mixed loop to the application ABI, verify RAM values/return in simulation,
   then upload it without rebuilding FPGA hardware. Compare board output and
   add the procedure and evidence to the user guide.

The [previous Gantt chart](report-6-previous-gantt.png) is byte-for-byte the
current chart embedded in Report 5. The [updated Gantt chart](report-6-current-gantt.png)
shows actual October 23 completion and planned build/board/application work.
Hardware dates depend on tool and board readiness; they are not completion claims.
