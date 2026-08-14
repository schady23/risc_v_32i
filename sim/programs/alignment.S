# Expand this program into separate expected-trap images for JAL, JALR, taken
# branches, LH/SH odd addresses, and non-word-aligned LW/SW. Untaken branches
# with misaligned computed targets must not trap.
    addi x1, x0, 1
    lh x2, 0(x1)
    ebreak
