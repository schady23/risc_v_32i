.section .text.init
.globl _start
.type _start, @function
_start:
    # Preserve the ROM loader's ABI state on its own stack before switching.
    addi sp, sp, -64
    sw ra, 0(sp)
    sw gp, 4(sp)
    sw s0, 8(sp)
    sw s1, 12(sp)
    sw s2, 16(sp)
    sw s3, 20(sp)
    sw s4, 24(sp)
    sw s5, 28(sp)
    sw s6, 32(sp)
    sw s7, 36(sp)
    sw s8, 40(sp)
    sw s9, 44(sp)
    sw s10, 48(sp)
    sw s11, 52(sp)
    mv s11, sp
    la sp, __stack_top
    la t0, __bss_start
    la t1, __bss_end
1:
    bgeu t0, t1, 2f
    sw zero, 0(t0)
    addi t0, t0, 4
    j 1b
2:
    call main
    # main must obey the standard RV32I ABI, including preserving s11.
    mv sp, s11
    lw ra, 0(sp)
    lw gp, 4(sp)
    lw s0, 8(sp)
    lw s1, 12(sp)
    lw s2, 16(sp)
    lw s3, 20(sp)
    lw s4, 24(sp)
    lw s5, 28(sp)
    lw s6, 32(sp)
    lw s7, 36(sp)
    lw s8, 40(sp)
    lw s9, 44(sp)
    lw s10, 48(sp)
    lw s11, 52(sp)
    addi sp, sp, 64
    ret
