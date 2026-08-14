# Writes a visible value and then increments the LED register forever.
.equ LED_ADDR, 0x40000000

    li t0, LED_ADDR
    li t1, 1
1:
    sw t1, 0(t0)
    addi t1, t1, 1
    j 1b
