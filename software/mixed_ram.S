.section .text
.globl main
.type main, @function
main:
    # Store and reload each running sum while counting from 1 through 5.
    la t0, results
    li t1, 1
    li t2, 6
    li t3, 0
1:
    add t3, t3, t1
    sw t3, 0(t0)
    lw t4, 0(t0)
    bne t4, t3, failed
    addi t0, t0, 4
    addi t1, t1, 1
    bne t1, t2, 1b

    # Independently check all five final RAM words against fixed constants.
    la t0, results
    la t1, expected
    li t2, 5
2:
    lw t3, 0(t0)
    lw t4, 0(t1)
    bne t3, t4, failed
    addi t0, t0, 4
    addi t1, t1, 4
    addi t2, t2, -1
    bnez t2, 2b
    la t1, passed_message
    li a0, 15
    j print_message
failed:
    la t1, failed_message
    li a0, 99
print_message:
    # Leaf function: use only caller-saved registers and preserve ra/s11.
    li t0, 0x40000000
3:
    lbu t2, 0(t1)
    beqz t2, 5f
4:
    lw t3, 8(t0)
    andi t3, t3, 1
    beqz t3, 4b
    sw t2, 0(t0)
    addi t1, t1, 1
    j 3b
5:
    ret

.section .rodata
.balign 4
expected:
    .word 1, 3, 6, 10, 15
passed_message:
    .asciz "Mixed RAM loop passed: 1 3 6 10 15\r\n"
failed_message:
    .asciz "Mixed RAM loop failed\r\n"

.section .bss
.balign 4
results:
    .zero 20
