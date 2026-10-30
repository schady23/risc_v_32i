# RV32I Architecture Contract

This document defines cycle-level and architectural behavior before CPU
implementation. Behavior not described here must be resolved here before it is
encoded in RTL.

The hardware target is the Terasic DE10-Lite. The decoder, multi-cycle core,
and board integration implement this contract. The [bring-up guide](bringup.md)
distinguishes simulation results, the completed Quartus build/timing checks,
and the captured board upload/rerun results from the remaining recovery tests.

## Scope

- ISA: RV32I, little-endian, `XLEN=32`, `IALIGN=32`.
- Included: all base integer instructions and byte, halfword, and word memory
  accesses.
- Excluded: M, A, C, F, D, CSR, interrupts, privilege levels, and `Zifencei`.
- `FENCE` with `funct3=000` retires as a no-op.
- `FENCE.I` with `funct3=001` is illegal because `Zifencei` is absent.
- Microarchitecture: non-pipelined, multi-cycle, single instruction in flight.
- Reset PC: `0x0000_0000`. On a rising edge with `reset_i='1'`, the
  core sets the PC to zero and enters `FETCH_REQ`; it issues the first fetch
  after reset is released.
- Register `x0` always reads zero and ignores writes. Both the core write
  enable and the register file reject destination register zero. Loads to
  `x0` still access memory and can trap; only their register write is suppressed.

## Instruction decoder

`rv32i_decoder` is combinational. It exposes raw register fields (`rs1_o`,
`rs2_o`, `rd_o`), a 32-bit immediate (`imm_o`), encoding legality (`legal_o`),
and a `decode_control_t` record (`ctrl_o`) defined in `rv32i_pkg`.

| Control field | Meaning |
| --- | --- |
| `kind` | ALU, LUI, AUIPC, JAL, JALR, branch, load, store, FENCE, ECALL, EBREAK, or illegal |
| `alu_op` | One of the ten existing ALU operations |
| `lhs_sel`, `rhs_sel` | Select `rs1`/PC/zero and `rs2`/immediate for the ALU |
| `rd_write` | Instruction requests destination writeback; the core must still suppress writes to `x0` and writes on traps |
| `wb_sel` | Select ALU result, extended memory-load result, or PC + 4 |
| `branch` | None, EQ, NE, signed LT/GE, or unsigned LT/GE |
| `mem_size` | Byte, halfword, or word, meaningful only for load/store |
| `load_unsigned` | Zero-extend byte/halfword loads when set; otherwise sign-extend |

I/S/B/J immediates are sign-extended; U immediates preserve instruction bits
31:12 and append twelve zeros. Branch and JAL immediates are byte offsets with
bit zero already inserted. Shift immediates are zero-extended five-bit shift
amounts, excluding the operation-select bits. Other instructions expose zero
as their immediate. Raw register fields remain available even where an
instruction format does not use them; the core interprets them using `kind`.

ALU operands compute results for arithmetic, effective addresses for loads and
stores, and targets for branches/jumps. Branch conditions compare the original
source registers separately. JAL/JALR write back PC + 4, not the target. LUI
uses zero + immediate, and AUIPC uses PC + immediate.

All encodings outside this project's RV32I subset are illegal, including
unsupported opcode/funct combinations, non-RV32 shift amounts, CSR operations,
privileged instructions, and FENCE.I. FENCE ignores `fm`, predecessor/successor,
`rs1`, and `rd` fields and is a no-op in this ordered, single-instruction design.
Only exact ECALL (`0x00000073`) and EBREAK (`0x00100073`) encodings are legal
SYSTEM instructions. They decode as legal instructions whose execution traps.
Supported instructions targeting `x0`, including HINT encodings, remain legal;
a load to `x0` must still perform its access and report any fault.

Illegal encodings produce `legal_o='0'`, zero immediate, and
`DECODE_CONTROL_ILLEGAL` (no destination write or memory instruction kind).
Simulation inputs containing unknown/high-impedance bits receive the same safe
decode. No decoder output directly asserts a bus request or commits state.
Target alignment, JALR bit-zero clearing, memory faults, and retirement belong
to the core's execution states.

Encoding references: [RV32I specification](https://docs.riscv.org/reference/isa/unpriv/rv32.html)
and [instruction encoding tables](https://docs.riscv.org/reference/isa/unpriv/rv-32-64g.html).

## Clock and reset

Use the DE10-Lite's `MAX10_CLK1_50` input at 50 MHz (20 ns period). The initial
design uses this clock directly for the core, memory bus, RAM, and UART, with no
PLL or derived fabric clock. Board pin and electrical details are in the
[bring-up guide](bringup.md#board-interface).

Use active-low `KEY(0)` as reset. The board wrapper drives
`not KEY(0)` into `reset_synchronizer.async_reset_i`; its output remains
active high internally. Assertion is asynchronous and release passes through
two flip-flops. Clocked CPU state observes that synchronized reset on active
edges. The synchronizer starts asserted, which is checked in simulation; verify
startup behavior on the board as well. Intel's generated JTAG IP handles its JTAG/system-clock crossing.

Changing the clock frequency changes elapsed execution time, not the number of
cycles in the request/response contract.

## Core memory interfaces

The first implementation uses fixed one-cycle request/response interfaces. No
`ready` or backpressure signal exists.

```vhdl
i_req, i_addr, i_rdata, i_fault

d_req, d_write, d_addr, d_wdata, d_be,
d_rdata, d_fault
```

Timing contract:

1. In a request cycle, the core asserts `i_req` or `d_req` and holds address,
   write data, write direction, and byte enables stable for the complete cycle.
2. The addressed device accepts the request on the active clock edge.
3. Read data and fault status are stable for the complete following response
   cycle. The core consumes them in its wait state.
4. A valid store commits on the edge that accepts its request. A rejected store
   makes no state change and reports `d_fault` in the following cycle.
5. The core issues at most one instruction request and one data request at a
   time. It does not issue another request on an interface until it consumes the
   prior response.

Each target registers its response, and the memory bus registers the target
selection in parallel. The response mux adds no extra clocked stage, so ROM,
RAM, MMIO, and unmapped-access faults all follow the same one-cycle timing.

At edge N, a request is accepted and the core enters its corresponding wait
state. Registered data/fault outputs become available after that edge and stay
available during the wait cycle; the core consumes them at edge N+1. There is
no ready/valid handshake or variable-latency retry. For a store, this response
is fault status, not read data; a valid store has already committed at edge N.

## Core state machine

The [Goal 1 state diagram](progress_reports/evidence/goal-1-state-diagram.png)
groups the request/wait states into instruction fetch and memory access. The
editable [Mermaid source](progress_reports/evidence/goal-1-state-diagram.mmd)
is saved alongside it. These are sequential stages of one instruction, not
pipeline stages. Loads/stores use memory access; other successful instructions
go directly from execute to writeback. Fetch and memory faults also enter
`HALT`, as shown below.

```text
RESET
  -> FETCH_REQ
  -> FETCH_WAIT
  -> DECODE
  -> EXECUTE
       -> WRITEBACK
       -> MEM_READ_REQ -> MEM_READ_WAIT -> WRITEBACK
       -> MEM_WRITE_REQ -> MEM_WRITE_WAIT -> WRITEBACK
       -> HALT

WRITEBACK -> FETCH_REQ
HALT      -> HALT until reset
FETCH_WAIT / MEM_READ_WAIT / MEM_WRITE_WAIT -> HALT on access fault
```

State responsibilities:

| State | Responsibility |
| --- | --- |
| `FETCH_REQ` | Drive the current PC and issue one instruction request. |
| `FETCH_WAIT` | Consume instruction data/fault and latch the instruction. |
| `DECODE` | Latch source register values; the combinational decoder supplies fields, immediate, and control. |
| `EXECUTE` | Compute results, targets, conditions, and effective addresses. |
| `MEM_READ_REQ` | Issue a load request with its effective address. |
| `MEM_READ_WAIT` | Consume load data/fault and perform lane extraction. |
| `MEM_WRITE_REQ` | Issue a store request with aligned data and byte enables. |
| `MEM_WRITE_WAIT` | Consume store fault status. |
| `WRITEBACK` | Atomically commit PC/register effects and pulse retirement. |
| `HALT` | Hold PC/register state, issue no bus requests or retirement, and retain trap information until reset. |

PC and register effects commit in `WRITEBACK`. Stores commit on their accepted
request edge, as specified by the memory interface, and retire after a
successful response. A rejected store has no memory or peripheral side effects.
A trapping instruction enters `HALT` without register writeback, retirement, or
PC update. The PC therefore remains the address of the faulting instruction.

## Address map

| Address range | Device | Access |
| --- | --- | --- |
| `0x0000_0000`-`0x0000_3FFF` | 16 KiB program ROM | instruction fetch and data reads |
| `0x0001_0000`-`0x0001_3FFF` | 16 KiB executable RAM | instruction fetch; byte, halfword, word data accesses |
| `0x4000_0000` | JTAG UART TX staging byte | aligned `SW` only, low 8 bits transmitted |
| `0x4000_0004` | JTAG UART RX staging byte | aligned `LW` only, zero-extended byte, pops FIFO |
| `0x4000_0008` | JTAG UART staging status | aligned `LW` only |

Unmapped accesses, writes to ROM, instruction fetches outside ROM and RAM, and
unsupported MMIO widths produce access faults. A faulting store does not alter
the target.

ROM and RAM use FPGA on-chip memory for the initial implementation. External
SDRAM and user flash are outside this address map and require separate future
design work. The September 30 Quartus build confirms RAM inference in four byte banks
using 16 M9Ks. Store response data is unspecified and is not consumed; read
responses retain the one-cycle timing above. Recheck inference and capacity
when images or memory RTL change.

### JTAG UART and executable RAM

The board uses its existing USB-Blaster/JTAG connection. The only user ports
are `MAX10_CLK1_50` and `KEY`; `KEY(0)` resets the system and `KEY(1)` is unused.
No UART TX/RX GPIO, LED, or switch ports are connected. Intel's generated JTAG
UART IP contains the JTAG circuitry, clock-domain crossing, and 64-byte RX/TX FIFOs.

`jtag_uart_adapter` preserves the CPU's one-cycle MMIO contract using a one-byte
RX staging register and one-byte TX staging register. An independent state
machine polls Intel's data/control registers and holds each Avalon read/write
until `waitrequest=0`. Writes use the low eight bits; RX reads use RVALID bit 15;
TX writes are attempted only after control WSPACE[31:16] reports space. RX is
serviced even when the host is not draining the Intel TX FIFO.

- CPU status bit 0: TX staging slot free; bit 1: RX staging byte available;
  bit 2: TX byte pending. Bits 31:3 read zero. Ready is a local staging status,
  not proof that the computer has consumed an outgoing byte.
- All CPU UART accesses require `d_be=1111`. TX reads, RX writes, status writes,
  subword accesses, empty RX reads, and busy TX writes fault without side effects.
- No interrupts, baud settings, framing-error flags, or serial pins are used.
- Reset clears staging and IP FIFOs and restarts the ROM loader. RAM remains.

Instruction routing now selects ROM or RAM and registers that selection in
parallel with the memory response. The existing four byte-bank RAM remains
single-ported. RAM instruction fetches force read-only access; RAM data accesses
use the usual byte enables. Requests are mutually exclusive in this CPU. If a
test or future master requests both RAM ports in one cycle, instruction fetch
wins and the data request faults without writing. Fetches from MMIO/unmapped
space fault. Both RAM boundaries are executable; the loader restricts uploads
to the application region by software policy.

### ROM loader and application convention

The resident loader starts at zero. Its workspace/stack occupies
`0x13C00`-`0x13FFF`. An uploaded image starts at `0x10000`, occupies at most
12 KiB (`0x10000`-`0x12FFF`), and uses a separate 3 KiB application stack
(`0x13000`-`0x13BFF`, initial SP `0x13C00`). These are conventions, not hardware
memory protection. The initial loader SP is `0x14000`.

The host assembles RV32I code, sends an `L` header with little-endian length
and CRC32, waits for SEND, and supplies chunks of at most 32 bytes. The CPU
credits each chunk with `+`, then verifies the complete CRC before allowing
`G` to call the fixed entry address. A rejected replacement invalidates any
previous image. A reset also invalidates the loaded-image flag.

`app_startup.S` preserves the loader's return address, GP, and callee-saved
registers on the loader stack, switches to the application stack, clears aligned
BSS, and calls `main`. On return it restores loader state and returns `a0` as
the exit value. Main must obey the standard RV32I ABI, including preserving
`s11`. Initialized application data is already in the uploaded flat image.
There is no cache, prefetch pipeline, or instruction-fence requirement.

Programs finish by returning, not by executing ECALL/EBREAK. The existing trap
behavior still halts until `KEY(0)` reset. An interrupted header/body also needs
reset; the loader does not interpret arbitrary bytes as assembly text. See
[JTAG UART and loader setup](uart.md) for the complete protocol.

## Endianness and byte enables

Memory is little-endian. For aligned word base `A = address & 0xFFFF_FFFC`:

| Address | Word bits | Enable |
| --- | --- | --- |
| `A + 0` | `7 downto 0` | `d_be(0)` |
| `A + 1` | `15 downto 8` | `d_be(1)` |
| `A + 2` | `23 downto 16` | `d_be(2)` |
| `A + 3` | `31 downto 24` | `d_be(3)` |

Store data is shifted into its addressed byte lanes before the request. `SB`
asserts one byte enable, `SH` two adjacent enables, and `SW` all four. Loads
select the addressed lane(s), then apply the instruction's sign or zero
extension.

## Alignment

- Every instruction fetch PC must be divisible by four.
- A `JAL` target must be divisible by four.
- `JALR` computes `(rs1 + immediate) & 0xFFFF_FFFE`, then requires the result
  to be divisible by four.
- A branch target is checked only when that branch is taken. An untaken branch
  does not trap due to its unused target.
- `LH`, `LHU`, and `SH` require an address divisible by two.
- `LW` and `SW` require an address divisible by four.
- `LB`, `LBU`, and `SB` allow any address.

Misaligned accesses trap and are never split into multiple bus requests.

## Traps

Trap cause values follow standard synchronous exception encodings:

| Value | Name | `trap_tval` |
| ---: | --- | --- |
| 0 | instruction-address-misaligned | bad target/PC |
| 1 | instruction-access-fault | faulting PC |
| 2 | illegal-instruction | instruction word |
| 3 | breakpoint (`EBREAK`) | zero |
| 4 | load-address-misaligned | effective address |
| 5 | load-access-fault | effective address |
| 6 | store-address-misaligned | effective address |
| 7 | store-access-fault | effective address |
| 11 | environment-call (`ECALL`) | zero |

The trap interface is level-based after a fault:

```vhdl
trap_valid
trap_cause
trap_pc
trap_tval
```

`trap_valid` remains asserted in `HALT` until reset. `trap_pc` is the PC of the
faulting instruction. A trapping instruction never asserts `retire_valid`.

## Retirement trace

The core emits one trace event for every successfully completed instruction:

```vhdl
retire_valid
retire_pc
retire_instr
retire_rd_we
retire_rd
retire_rd_data
```

`retire_valid` is a one-cycle pulse in `WRITEBACK`. `retire_rd_we` is asserted
only when the instruction commits a write to a destination other than `x0`.
Branches, stores, and `FENCE` retire with `retire_rd_we='0'`. Trace values remain
stable for the cycle in which `retire_valid='1'`.

## Verification progression

1. Unit test ALU, register file, decoder, and byte-lane behavior.
2. Test fixed-latency bus requests, mapped accesses, and faults.
3. Run small hand-written assembly programs and compare retirement traces.
4. Run a mixed instruction program.
5. Run RISC-V Architectural Certification Tests configured for this RV32I DUT.
6. Run Quartus synthesis, fitting, and timing analysis for the MAX 10 target.
7. Run JTAG program upload, execution, return, and reset checks on the DE10-Lite.

Required directed alignment tests include `JAL`, `JALR`, taken and untaken
branches, odd-address `LH`/`SH`, and non-word-aligned `LW`/`SW`.

The [simulation guide](../sim/README.md) distinguishes the tests available now
from planned coverage. The [bring-up guide](bringup.md) defines board acceptance
criteria and the implemented DE10-Lite wrapper test.
