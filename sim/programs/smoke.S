# Transmits an ASCII 'U' repeatedly. Full boot/echo firmware: software/uart_echo.S.
.equ UART_BASE, 0x40000000

    li t0, UART_BASE
    li t1, 0x55
1:
    lw t2, 8(t0)
    andi t2, t2, 1
    beqz t2, 1b
    sw t1, 0(t0)
    j 1b
