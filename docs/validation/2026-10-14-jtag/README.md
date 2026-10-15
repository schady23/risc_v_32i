# JTAG UART and ROM loader verification - October 14, 2026

This record supersedes the physical-UART bring-up design. The active source
uses Intel JTAG UART through USB-Blaster, a ROM CRC32 loader and executable RAM.

| Check | Result |
| --- | --- |
| Firmware | GCC 12.2.0, RV32I/ILP32; 890-byte loader, reset entry 0 |
| Uploadable assembly | 328-byte hello image, entry `0x10000`; initialized data/BSS and return-value checks |
| `make test` | Eight fixed benches, 13 directed programs and five host protocol tests passed |
| Decoder | 270,612 cases passed |
| JTAG adapter | Invalid MMIO, waitrequest stability, exact byte order, full TX FIFO backpressure, independent RX, reset passed |
| Board/loader simulation | Upload/CRC, three invalid sizes, RAM execution, initialized data, BSS clearing, return/re-run, bad replacement CRC, reset during upload passed |
| Host protocol | Padding, fragmented/coalesced replies, 12 KiB maximum image, 32-byte credits, CRC rejection, no-image error and timeout passed |
| Architectural adapter | Local GNU pass/fail/trap/timeout checks passed; no upstream certification run |
| GHDL synthesis | `rv32i_system` accepted; ROM and four 4096x8 byte-bank RAMs inferred |
| Loader stack | GCC reports main 64 bytes, puts 16, byte helpers 0; app entry saves 64 more bytes on loader stack before switching |
| PDF | Four pages generated, rendered, visually inspected; box text width checks pass |
| Native Intel IP / hardware | Not tested: Intel IP generation, Quartus fit/timing, native host DLLs, physical USB-Blaster communication |

GHDL version is 6.0.0, Windows mcode backend. The board simulation binds a
test-only Avalon/FIFO model to `jtag_uart_system`; it does not simulate Intel's
JTAG scan protocol, clock-domain crossing, or native host libraries. Quartus
sources exclude that model and instead include the generated Intel QIP.

Transcripts:

- [Simulation and host tests](simulation-and-host.txt)
- [Architectural adapter](adapter.txt)
- [Synthesis diagnostics](synthesis.txt)
- [Image sizes and hashes](images.txt)

ROM loader binary SHA256:

```text
77afb20087000bab0f110a8e5f743ab0ae86034ba4727467186a10fb4b95366a
```

Application binary SHA256:

```text
74f6b01622bb7e177c85fe9fca7c1c7c317431bceb0c4e3776f664253c9f3979
```

The tests retain known time-zero numeric_std settling warnings. GHDL synthesis
ignores the Quartus-specific `ramstyle` attribute; actual M9K fitting and all
generated JTAG timing constraints still require Quartus.

For hardware acceptance, follow [board bring-up](../../bringup.md) and the
[JTAG UART/loader guide](../../uart.md). Earlier GPIO/physical-UART SOF, resource
and timing reports do not establish this design's hardware behavior.
