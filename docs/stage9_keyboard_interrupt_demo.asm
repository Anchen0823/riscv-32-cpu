# Stage 9 keyboard interrupt demo program
#
# I/O map:
#   0xffff000c  SEG7_DATA
#   0xffff0010  KBD_DATA
#   0xffff0014  KBD_STATUS, bit0 ready/irq, write 1 to clear
#   0xffff0018  IRQ_RET, write 1 to return from interrupt
#
# The interrupt vector is fixed at 0x00000100.

    lui  x5, 0xffff0
main:
    jal  x0, main

    # The ROM image is padded with nop until address 0x00000100.

irq_handler:
    lui  x5, 0xffff0
    lw   x10, 16(x5)
    sw   x10, 12(x5)
    addi x11, x0, 1
    sw   x11, 20(x5)
    sw   x11, 24(x5)
irq_halt:
    jal  x0, irq_halt
