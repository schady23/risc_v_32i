# Progress Report 4 goal completion

Goal 1 was completed on October 12, 2026. Goals 2 and 3 were completed and
simulated on October 15, 2026. These dated additions follow Report 4's original
September 30 through October 7 reporting period; the simulations are not backdated.
Report 5 reports these outcomes and identifies the October 15 verification supplement.

## Goal 1 complete

The [HDL review](goal-1-hdl-review.md), [state diagram](goal-1-state-diagram.png)
and editable [Mermaid source](goal-1-state-diagram.mmd) document reset PC zero,
x0 protection, the sequential core states and the one-cycle memory interface.
The review's GPIO address map records the October 12 implementation. The
October 14 JTAG UART implementation superseded GPIO at those three addresses;
the current contract is [architecture.md](../../architecture.md). ROM remains
16 KiB at 0x00000000; 16 KiB RAM at 0x00010000 now also supports instruction fetch.
The state diagram remains applicable to the current core.

## Goal 2 complete

`sim/tb_decoder_focused.vhd` applies seven fixed instructions at 10 ns intervals.
It checks legality, raw register fields, the immediate and every control-record
field after 1 ns of combinational settling. All seven cases pass at 70 ns.

| Time ns | Instruction | Immediate | Kind | Write intent | Writeback |
| --- | --- | --- | --- | --- | --- |
| 0 to 10 | ADDI x1,x0,-1 | FFFFFFFF | ALU | 1 | ALU |
| 10 to 20 | LW x2,12(x1) | 0000000C | LOAD | 1 | memory |
| 20 to 30 | SW x2,-4(x1) | FFFFFFFC | STORE | 0 | unused |
| 30 to 40 | BEQ x1,x2,8 | 00000008 | BRANCH | 0 | unused |
| 40 to 50 | JAL x3,16 | 00000010 | JAL | 1 | PC plus 4 |
| 50 to 60 | FFFFFFFF illegal | 00000000 | ILLEGAL | 0 | unused |
| 60 to 70 | NOP recovery | 00000000 | ALU | 1 | ALU |

The [waveform](goal-2-decoder-waveform.png) shows sign extension for negative
ADDI/SW immediates, word width for LW/SW, and register-write intent only for
ADDI/LW/JAL/NOP. BEQ selects PC and EQ; JAL selects PC plus 4 for writeback.
At 50 ns the illegal instruction clears legality and write intent; NOP restores
legal decoding at 60 ns. NOP's write intent is valid because the core separately
blocks destination x0. Size/control defaults for non-memory instructions have
no memory side effects; this bench tests decoding, not instruction execution.

Raw traces: [GHW](goal-2-decoder.ghw), [VCD](goal-2-decoder.vcd).
Assertions: [simulation transcript](goal-2-decoder-simulation.txt).
GHW retains the original typed record/enums. VCD includes enum-position aliases
whose order is defined in `rv32i_pkg`; the PNG translates actual VCD values.

## Goal 3 complete

`sim/tb_core_reset.vhd` uses the actual core, register file, memory bus and RAM
with an independent seven-instruction ROM. It injects three resets away from
rising clock edges and checks both immediate output suppression and clocked
effects. All assertions pass; the simulation ends at 1165 ns.

The [waveform](goal-3-reset-waveform.png) compares two store boundaries:

- Panel A: reset rises at 290 ns during the store request, before acceptance
  at the next rising edge. Data/store requests drop immediately, and the
  accepted-store counter stays zero. Reset is held through the 295/305 ns
  edges; release at 310 ns produces a fetch at address zero.
- Panel B: the store is accepted at 575 ns, then reset rises at 580 ns in the
  response wait cycle. The accepted-store counter remains one through reset.
  Release at 600 ns restarts fetch at zero, and a later load returns 0x55,
  proving that reset preserved the already committed RAM write.

In both panels retirement and register-write enable stay low throughout reset.
A third reset at 930 ns suppresses an ADDI's pending writeback before its commit
edge. Each restart also checks ADDI x7,x6,1 returns 1 after x6 previously held
0x55, demonstrating register-file clearing. These are three focused scenarios;
they do not establish reset coverage across every state or physical reset timing.

Raw traces: [GHW](goal-3-reset.ghw), [VCD](goal-3-reset.vcd).
Assertions: [simulation transcript](goal-3-reset-simulation.txt).

## Reproduce and regression

Run `python scripts/report4_evidence.py` with GHDL on PATH or exported as `GHDL`.
Pillow is needed for PNG plots. The script saves both raw formats and generates
the figures directly from measured VCD transitions.

The [regression](report-4-regression.txt) passes ten fixed benches, including
270,612 exhaustive decoder cases, and thirteen directed execution programs.
The [host checks](report-4-host-tests.txt) pass five protocol tests. Existing
time-zero numeric_std settling warnings remain. Local architectural adapter
[pass/fail/trap/timeout checks](report-4-adapter.txt) and
[GHDL system synthesis](report-4-synthesis.txt) also pass. The
[verification manifest](report-4-verification.json) records source/report hashes,
waveform hashes, page counts and template preservation checks. Native Intel
JTAG IP generation, current Quartus fit/timing and physical board testing remain
pending; the GHDL Avalon model does not establish hardware JTAG operation.
