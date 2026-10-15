.section .text
.globl main
.type main, @function
main:
    # Check initialized data and BSS clearing, including a second run.
    la t4, bss_value
    lw t5, 0(t4)
    bnez t5, 4f
    li t5, 123
    sw t5, 0(t4)
    la t4, initialized_value
    lw t5, 0(t4)
    li t6, 7
    bne t5, t6, 4f
    li t0, 0x40000000
    la t1, message
1:
    lbu t2, 0(t1)
    beqz t2, 3f
2:
    lw t3, 8(t0)
    andi t3, t3, 1
    beqz t3, 2b
    sw t2, 0(t0)
    addi t1, t1, 1
    j 1b
3:
    li a0, 42
    ret
4:
    li a0, 99
    ret
.section .rodata
message:
    .asciz "Hello from uploaded RV32I assembly!\r\n"
.section .data
.balign 4
initialized_value:
    .word 7
.section .bss
.balign 4
bss_value:
    .zero 4
