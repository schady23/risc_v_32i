# Directed branch/jump placeholder, including taken and untaken conditions.
    addi x1, x0, 1
    beq x1, x0, 1f
    jal x2, 2f
1:
    ebreak
2:
    ebreak
