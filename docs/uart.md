# JTAG UART and program loader

The FPGA communicates with the computer through its existing **USB-Blaster**.
Intel's JTAG UART transports bytes over JTAG; it does not use asynchronous
TX/RX pins, a serial adapter, COM ports, start/stop bits, or a baud rate.
The ROM loader receives compiled RV32I programs, checks their CRC32, stores
them in executable RAM, and calls the entry point.

## First-time setup

1. Connect and power the DE10-Lite through its normal USB-Blaster connection.
2. Install Quartus Prime Lite/Standard with MAX 10, Platform Designer, and the
   USB-Blaster driver. See [board bring-up](bringup.md).
3. Build/test the sources, then generate a new FPGA image and program it:

```sh
make test
make build
make program
```

`make build` generates the Intel JTAG UART IP using the installed Quartus
version. An old GPIO or physical-UART .sof will not provide this loader.
The checked-in ROM already contains the loader. `make image` rebuilds it from
`software/startup.S` and `software/loader.c` when a RISC-V toolchain is available.

Install the host binding:

```sh
python -m pip install -r software/requirements.txt
python scripts/jtag_console.py console
```

The helper uses `intel-jtag-uart` 0.0.3, an MIT-licensed Python binding to the
native Quartus `jtag_atlantic` and `jtag_client` libraries. Its library discovery
uses `QUARTUS_ROOTDIR` when needed. With a nonstandard installation:

```sh
python scripts/jtag_console.py --quartus-root C:/intelFPGA_lite/25.1/quartus console
```

Use your actual installation path. Match Python's architecture to the native
libraries (normally 64-bit). On Linux, the Quartus library directories may also
need to be on `LD_LIBRARY_PATH`; follow your Quartus installation's setup.
Close other JTAG UART clients before opening this one. Programming and terminal
use should be performed sequentially.

Press and release `KEY(0)` to see:

```text
RV32I JTAG loader v1
ready>
```

The console is line-oriented: type `?` and press Enter for help; Ctrl+C exits.
The loader ignores CR/LF between commands. An Intel JTAG terminal supplied
with your installation can also display text, but the Python helper handles
the program-upload protocol.

## Build, upload and run an assembly program

```sh
python scripts/build_app.py software/hello.S
python scripts/jtag_console.py upload software/build/hello.bin --run
```

The first command assembles/links the source with `app_startup.S` and `app.ld`.
The default compiler prefix is `riscv64-unknown-elf-`; pass `--prefix` with a
different prefix or full tool directory, or export `RISCV_PREFIX`.
The ELF, binary, disassembly, and object files go under `software/build/`.

The example prints `Hello from uploaded RV32I assembly!`, returns 42, and the
loader prints `EXIT 0000002A` followed by its prompt. It also checks initialized
data and BSS clearing. To run it again without uploading:

```sh
python scripts/jtag_console.py run
```

Change the assembly, rebuild it and upload the new binary. The FPGA .sof and
ROM loader do not need rebuilding for application changes.

The second example, `software/mixed_ram.S`, combines arithmetic, backward
branches, stores, and loads. It stores the running sums of 1 through 5 into a
20-byte BSS array, immediately reloads each value, and then checks all five
final RAM words against the fixed expected values 1, 3, 6, 10, and 15.
Build and upload it after testing hello, using the same FPGA configuration:

```sh
python scripts/build_app.py software/mixed_ram.S
python scripts/jtag_console.py upload software/build/mixed_ram.bin --run
python scripts/jtag_console.py run
```

Both runs must produce:

```text
RUN
Mixed RAM loop passed: 1 3 6 10 15
EXIT 0000000F
ready>
```

A failed RAM check prints `Mixed RAM loop failed` and returns `EXIT 00000063`.
`make app` builds both examples and regenerates their checked-in simulation
images. The integration bench uploads and runs each through the real loader
with the simulated Avalon/FIFO transport. Save the physical board output and
a photo with the tested SOF hash when completing the hardware acceptance.

To select a specific cable/device/instance, put options before the subcommand:

```sh
quartus_pgm --list
python scripts/jtag_console.py --cable "USB-Blaster [1-1]" upload software/build/hello.bin --run
```

Use the actual cable name. `--device` and `--instance` default to automatic
selection (`-1`); use the numbers reported by Intel's tools if multiple targets
exist. `--timeout 60` allows a program that takes longer to return. Programs
requiring live input should be uploaded without `--run`, then run from the
interactive console by typing `G`; the upload helper's `--run` waits for completion.

## Application requirements

- Use RV32I instructions, without compressed, multiply/divide, CSR, or floating
  point extensions. The builder selects `-march=rv32i -mabi=ilp32`.
- Export `main`. Assembly main must preserve any `s0`-`s11` registers it changes
  and preserve `ra` if it makes calls. Return the exit value in `a0` using `ret`.
- `app_startup.S` runs at `0x10000`, saves the loader's callee-saved registers,
  GP and return address, switches stacks, clears BSS, and calls main. It uses
  `s11` to retain the loader stack pointer, so main must follow the ABI.
- Initialized `.data` is included in the uploaded image. BSS is cleared for
  each run. Modified initialized data remains modified until a new upload.
- Do not use ECALL/EBREAK to finish: this core halts on those instructions.
- The image's code/data/BSS must fit in 12 KiB. The linker checks that boundary.
  The uploader pads the flat binary to a four-byte length before calculating CRC.
- Bare-metal C main is also supported, but no libc/printf or automatic software
  arithmetic support library is linked. Use the memory-mapped byte interface.

## RAM layout

| Addresses | Purpose |
| --- | --- |
| `0x00000000`-`0x00003FFF` | 16 KiB ROM, loader/startup/constants |
| `0x00010000`-`0x00012FFF` | 12 KiB application image, data and BSS |
| `0x00013000`-`0x00013BFF` | 3 KiB application stack; initial SP `0x13C00` |
| `0x00013C00`-`0x00013FFF` | 1 KiB loader workspace/stack; initial SP `0x14000` |

The entire 16 KiB RAM supports instruction fetches. The loader's upload bound
and application linker enforce the above convention; there is no hardware
memory protection. A program that overwrites the loader stack can prevent return.

## CPU-facing I/O registers

These are the project's staging registers, not Intel's native Avalon register
map. Access them with aligned 32-bit `LW`/`SW` (`be=1111`).

| Address | Access | Meaning |
| --- | --- | --- |
| `0x40000000` | `SW` only | Queue low eight bits in TX staging; busy slot faults |
| `0x40000004` | `LW` only | Consume RX staging byte, zero-extended; empty slot faults |
| `0x40000008` | `LW` only | Bit 0 TX-ready; bit 1 RX-ready; bit 2 TX-pending; other bits zero |

Poll bit 0 before TX writes and bit 1 before RX reads. Invalid directions,
subword accesses and status writes fault. TX-ready means the local slot can
accept a byte; it does not mean the PC has already received previous bytes.

The adapter independently reads Intel's data register, checks RVALID bit 15,
polls WSPACE[31:16] in the control register, and sends queued data only when
space exists. It holds Avalon requests while waitrequest is asserted. Intel IP
has 64-byte RX/TX FIFOs and handles the JTAG/system clock crossing.

## Upload protocol

The helper sends binary machine code, not assembly text:

1. `?` requests a fresh help response and prompt to synchronize the connection.
2. `L` followed by little-endian `uint32 length` and `uint32 crc32` requests a
   replacement. Length must be nonzero, divisible by four and at most 12288.
3. The loader invalidates any old image. An invalid header returns `ERR size`
   and a prompt. A valid header returns `SEND\r\n` before accepting the body.
4. The host sends up to 32 bytes and waits for `+`. The CPU stores those bytes
   and updates CRC32 before granting the next credit. The last chunk may be shorter.
5. CRC32 uses polynomial `0xEDB88320`, initial value `0xFFFFFFFF`, final XOR
   `0xFFFFFFFF` (matching Python `zlib.crc32`). It covers all padded image bytes.
6. A match produces `LOADED` and enables `G`; a mismatch produces `ERR crc`
   and leaves execution disabled. Neither response starts the program.
7. `G` calls `0x10000` or reports `ERR no image`. Normal return prints an
   eight-digit hexadecimal exit value and another prompt.

## Recovery and verification limits

`KEY(0)` resets the CPU, staging registers and Intel FIFOs. RAM bytes remain,
but the loader's authorization flag is cleared, so upload again. Use reset
after a program hangs/traps or a connection breaks partway through a header
or body. The loader has no asynchronous abort or hardware debugger.

The CPU/ROM/RAM/adapter path is tested with a FIFO/Avalon model in GHDL. Host
protocol tests use an independent peer. The October 29
[build and timing record](validation/2026-10-29-jtag-timing/README.md) documents
the current Intel IP and successful full build. The
[board photo and console screenshot](validation/2026-10-29-board/README.md)
document physical upload, CRC verification, execution and rerun of both
applications through the native JTAG libraries and USB-Blaster. Recorded
reset-after-upload and interrupted-transfer/bad-CRC recovery checks remain
the next hardware acceptance work. The earlier
[verification record](validation/2026-10-14-jtag/README.md) retains its dated scope.

References: [Intel JTAG UART documentation](https://www.intel.com/programmable/technical-pdfs/683130.pdf)
and the [Python binding's source/documentation](https://github.com/tomverbeure/intel_jtag_uart).
