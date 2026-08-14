# RV32I Architecture Contract

This document defines cycle-level and architectural behavior before CPU
implementation. Behavior not described here must be resolved here before it is
encoded in RTL.

## Scope

- ISA: RV32I, little-endian, `XLEN=32`, `IALIGN=32`.
- Included: all base integer instructions and byte, halfword, and word memory
  accesses.
- Excluded: M, A, C, F, D, CSR, interrupts, privilege levels, and `Zifencei`.
- `FENCE` with `funct3=000` retires as a no-op.
- `FENCE.I` with `funct3=001` is illegal because `Zifencei` is absent.
- Microarchitecture: non-pipelined, multi-cycle, single instruction in flight.
- Reset PC: `0x0000_0000`.
- Register `x0` always reads zero and ignores writes.

## Clock and reset

The Basys 3 input clock is 100 MHz on package pin W5. `btnC` is an asynchronous,
active-high board input. The board wrapper asynchronously asserts internal reset
and synchronizes its release through two flip-flops. All CPU state uses this
active-high synchronized reset.

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

The memory bus registers responses from every target, including MMIO, so that
all devices present identical timing to the core.

## Core state machine

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
```

State responsibilities:

| State | Responsibility |
| --- | --- |
| `FETCH_REQ` | Drive the current PC and issue one instruction request. |
| `FETCH_WAIT` | Consume instruction data/fault and latch the instruction. |
| `DECODE` | Extract fields/immediates and read source registers. |
| `EXECUTE` | Compute results, targets, conditions, and effective addresses. |
| `MEM_READ_REQ` | Issue a load request with its effective address. |
| `MEM_READ_WAIT` | Consume load data/fault and perform lane extraction. |
| `MEM_WRITE_REQ` | Issue a store request with aligned data and byte enables. |
| `MEM_WRITE_WAIT` | Consume store fault status. |
| `WRITEBACK` | Atomically commit PC/register effects and pulse retirement. |
| `HALT` | Hold all architectural state and bus requests inactive. |

An instruction updates architectural state only in `WRITEBACK`. A trapping
instruction enters `HALT` without register writeback, retirement, or PC update.
The PC therefore remains the address of the faulting instruction.

## Address map

| Address range | Device | Access |
| --- | --- | --- |
| `0x0000_0000`-`0x0000_3FFF` | 16 KiB program ROM | instruction fetch and data reads |
| `0x0001_0000`-`0x0001_3FFF` | 16 KiB data RAM | byte, halfword, word reads/writes |
| `0x4000_0000` | LED output | aligned `LW`/`SW` |
| `0x4000_0004` | switch input | aligned `LW` only |
| `0x4000_0008` | debug status | aligned `LW` only |

Unmapped accesses, writes to ROM, instruction fetches outside ROM, and
unsupported MMIO widths produce access faults. A faulting store does not alter
the target.

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
6. Run Vivado synthesis, implementation, and timing analysis.
7. Run LED-visible smoke and CPU programs on the Basys 3.

Required directed alignment tests include `JAL`, `JALR`, taken and untaken
branches, odd-address `LH`/`SH`, and non-word-aligned `LW`/`SW`.
