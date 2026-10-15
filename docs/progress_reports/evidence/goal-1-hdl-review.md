# Goal 1 HDL review

Reviewed October 12 2026 for Progress Report 4. This is a source review of the
existing implementation; no new simulation or physical FPGA test was run.

Historical scope: the GPIO entries below describe October 12. GPIO was replaced
by JTAG UART on October 14; the same three addresses now serve TX, RX and status.
RAM now also supports instruction fetch. See the current
[architecture contract](../../architecture.md) and the
[October 15 completion record](report-4-completion.md). The core state diagram,
reset, x0 and fixed response timing still apply.

| Item | Verified behavior | HDL authority |
| --- | --- | --- |
| Reset PC | Rising edge with reset asserted sets PC to `0x00000000` and state to `FETCH_REQ`; requests are suppressed until reset is released. | `rtl/core/rv32i_core.vhd` reset branch and request assignments |
| x0 | Both read ports return zero for register zero. The core and register file suppress writes to zero. Loads to x0 still execute and can fault. | `rtl/core/rv32i_regfile.vhd`; `rtl/core/rv32i_core.vhd` write-enable and load states |
| Program ROM | `0x00000000`–`0x00003FFF` inclusive, 16 KiB; instruction fetch and data reads; data writes fault. | `rtl/pkg/memory_map_pkg.vhd`; `rtl/memory/instruction_rom.vhd`; `rtl/interconnect/memory_bus.vhd` |
| Data RAM | `0x00010000`–`0x00013FFF` inclusive, 16 KiB; byte, halfword, and word accesses with core alignment checks. | `rtl/pkg/memory_map_pkg.vhd`; `rtl/memory/data_ram.vhd`; `rtl/core/rv32i_core.vhd` |
| LED GPIO | Exact address `0x40000000`, aligned word reads/writes; low 16 bits stored, low 10 connected to board LEDs. | `rtl/peripheral/gpio.vhd`; `rtl/board/de10_lite_top.vhd` |
| Switch GPIO | Exact address `0x40000004`, aligned word reads only; synchronized input; upper six board input bits tied to zero. | `rtl/peripheral/gpio.vhd`; `rtl/board/de10_lite_top.vhd` |
| Status GPIO | Exact address `0x40000008`, aligned word reads only; board wrapper currently supplies zero. | `rtl/peripheral/gpio.vhd`; `rtl/board/de10_lite_top.vhd` |
| Memory response | Request accepted at edge N; registered data/fault is available during the wait cycle and consumed at edge N+1. Bus target selection is registered in parallel, with no extra response register. Valid stores commit at edge N. | `rtl/interconnect/memory_bus.vhd`; `rtl/memory/instruction_rom.vhd`; `rtl/memory/data_ram.vhd`; `rtl/memory/ram_byte_bank.vhd`; `rtl/peripheral/gpio.vhd`; `rtl/core/rv32i_core.vhd` |
| Halt | Fetch fault, execution trap, or data access fault enters HALT. No register write, PC update, or retirement for the trapping instruction; reset clears the trap and restarts fetch. | `rtl/core/rv32i_core.vhd` |

Clarified `docs/architecture.md`: reset edge behavior, x0 write protection,
loads to x0, request/response edge timing, operand latching in DECODE, and
fetch/data fault paths to HALT. Existing address values required no correction.

Diagram evidence: [PNG](goal-1-state-diagram.png) and editable
[Mermaid source](goal-1-state-diagram.mmd). The six boxes group sequential HDL
states; they do not represent a pipeline. `READ_REQ/WAIT` and `WRITE_REQ/WAIT`
in the PNG abbreviate the HDL's `MEM_READ_REQ/WAIT` and `MEM_WRITE_REQ/WAIT`.

Progress Report 4 now includes a dated Goal 1 evidence page and the clarified
architecture summary. Its original weekly goals and earlier reporting period
remain intact.
