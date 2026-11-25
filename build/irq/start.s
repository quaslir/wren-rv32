    .section .text.start
    .globl _start
_start:
    li sp, 4096
    call main
    add a0, a0, x0
halt:
    beq x0, x0, halt
