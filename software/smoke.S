.equ LED_ADDR, 0x40000000

.section .text
.globl main
.type main, @function

main:
    li t0, LED_ADDR
    li t1, 1

.Lcount:
    sw t1, 0(t0)
    addi t1, t1, 1
    j .Lcount
