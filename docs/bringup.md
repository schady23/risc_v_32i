# Basys 3 Bring-Up

## Prerequisites

- AMD Vivado with Artix-7 device support.
- Digilent/JTAG cable drivers.
- A Basys 3 board connected by USB with its power switch on.

The software flow additionally requires GNU Make, Python 3, and a bare-metal
RISC-V GNU toolchain.

## Build the smoke bitstream

Start Vivado in Tcl mode from the repository root and run:

```tcl
source scripts/create_project.tcl
source scripts/build.tcl
```

The build script writes
`build/vivado/risc_v_32i/risc_v_32i.runs/impl_1/basys3_top.bit`.
It also fails if implementation timing is not met.

## Program the board

With the board attached, use the same Vivado Tcl session:

```tcl
source scripts/program.tcl
```

Expected smoke behavior:

- `led(14 downto 0)` mirrors `sw(14 downto 0)`.
- `led(15)` blinks slowly.
- Holding `btnC` turns all LEDs off.
- Releasing `btnC` resumes operation synchronously to the board clock.

## CPU bring-up checklist

After `basys3_top.vhd` is converted from the smoke design to the CPU system:

1. Program a ROM image that writes a fixed value to the LED register.
2. Confirm reset restarts execution from `0x0000_0000`.
3. Display `trap_valid` and low trap-cause bits on reserved LEDs.
4. Run load/store and branch loops before larger software.
5. Preserve the post-route timing report with test results.
