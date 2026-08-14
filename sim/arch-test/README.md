# RISC-V Architectural Tests

Integrate `riscv/riscv-arch-test` after the hand-written programs pass. Configure
the DUT for RV32I only, little-endian operation, `IALIGN=32`, no misaligned data
access support, and no optional extensions. The adapter should terminate tests
through the memory-mapped signature/status mechanism rather than requiring a
privileged trap handler.

Architectural tests complement, but do not replace, the directed timing,
alignment, trap, and retirement-interface testbenches in this repository.
