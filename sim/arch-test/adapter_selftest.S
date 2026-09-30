/* Adapter plumbing test only; this is not an upstream certification test. */
.option norvc
.section .text
.globl _start
_start:
    lui t0, 0x14
    addi t0, t0, -4        /* 0x00013ffc: reserved completion RAM word */
    addi t1, zero, 1       /* 1 = pass; any other value = fail */
    sw t1, 0(t0)
1:  jal zero, 1b
