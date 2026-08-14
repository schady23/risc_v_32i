.section .text.init
.globl _start
.type _start, @function

_start:
    la sp, __stack_top
    la t0, __bss_start
    la t1, __bss_end

.Lclear_bss:
    bgeu t0, t1, .Lrun
    sw zero, 0(t0)
    addi t0, t0, 4
    j .Lclear_bss

.Lrun:
    call main

.Lhalt:
    ebreak
    j .Lhalt
