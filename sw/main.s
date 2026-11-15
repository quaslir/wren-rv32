.global _start

.text



_start:
addi x1, x0, 20
addi x2, x0, 0
addi x3, x0, 1
addi x4, x0, 1
addi x5, x0, 0


loop_start:

add x6, x2, x3
add x2, x0, x3
add x3, x0, x6
addi x4, x4, 1
beq x1, x4, loop_end

beq x0, x0, loop_start

loop_end:
    add x10, x3, x0

hang:
    beq x0, x0, hang
