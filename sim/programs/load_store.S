# Directed little-endian load/store placeholder.
    lui x1, 0x10
    addi x2, x0, 0x7f
    sw x2, 0(x1)
    lw x3, 0(x1)
    ebreak
