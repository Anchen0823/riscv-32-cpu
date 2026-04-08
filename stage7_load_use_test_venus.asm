# Stage-7 test for Venus: 通用 load-use hazard 检测 + 停顿
# 与硬件仿真版逻辑一致，但把测试内存放在 .data，避免写 text 段报错。

.data
test_mem:
    .word 123     # [0]
    .word 5       # [4]
    .word 20      # [8]
    .word 77      # [12]
    .word 9       # [16]
    .word 14      # [20]
    .word 0       # [24] 用于 Case3 回写校验

.text
main:
        addi    x30, x0, 0          # pass counter
        addi    x31, x0, 0          # status code
        la      x1, test_mem        # base addr in writable data segment

        lw      x2,  4(x1)          # x2 = 5
        lw      x3,  8(x1)          # x3 = 20
        lw      x4,  0(x1)          # x4 = 123
        lw      x5, 12(x1)          # x5 = 77
        lw      x7, 16(x1)          # x7 = 9
        lw      x8, 20(x1)          # x8 = 14

        # ------------------------------------------------------------
        # Case1: load -> ALU (rs1)
        # ------------------------------------------------------------
        lw      x10, 4(x1)          # x10 = 5
        add     x11, x10, x2        # x11 = 10
        addi    x12, x0, 10
        bne     x11, x12, fail1
        addi    x30, x30, 1

        # ------------------------------------------------------------
        # Case2: load -> ALU (rs2)
        # ------------------------------------------------------------
        lw      x13, 8(x1)          # x13 = 20
        sub     x14, x3, x13        # x14 = 0
        bne     x14, x0, fail2
        addi    x30, x30, 1

        # ------------------------------------------------------------
        # Case3: load -> store data (rs2)
        # ------------------------------------------------------------
        lw      x15, 12(x1)         # x15 = 77
        sw      x15, 24(x1)         # test_mem[6] = 77
        lw      x16, 24(x1)         # x16 = 77
        bne     x16, x5, fail3
        addi    x30, x30, 1

        # ------------------------------------------------------------
        # Case4: load -> branch compare (rs1)
        # ------------------------------------------------------------
        lw      x17, 16(x1)         # x17 = 9
        beq     x17, x7, c4_ok
        jal     x0, fail4
c4_ok:
        addi    x30, x30, 1

        # ------------------------------------------------------------
        # Case5: load -> branch compare (rs2)
        # ------------------------------------------------------------
        lw      x18, 20(x1)         # x18 = 14
        beq     x8,  x18, c5_ok
        jal     x0, fail5
c5_ok:
        addi    x30, x30, 1

        # ------------------------------------------------------------
        # Case6: load -> ALU -> branch
        # ------------------------------------------------------------
        lw      x19, 0(x1)          # x19 = 123
        addi    x20, x19, 1         # x20 = 124
        addi    x21, x0, 124
        beq     x20, x21, c6_ok
        jal     x0, fail6
c6_ok:
        addi    x30, x30, 1

        # final check: x30 must be 6
        addi    x22, x0, 6
        bne     x30, x22, fail_final
        addi    x31, x0, 7          # PASS signature
        jal     x0, end

fail1:
        addi    x31, x0, 1
        jal     x0, end
fail2:
        addi    x31, x0, 2
        jal     x0, end
fail3:
        addi    x31, x0, 3
        jal     x0, end
fail4:
        addi    x31, x0, 4
        jal     x0, end
fail5:
        addi    x31, x0, 5
        jal     x0, end
fail6:
        addi    x31, x0, 6
        jal     x0, end
fail_final:
        addi    x31, x0, 15
        jal     x0, end

end:
        jal     x0, end
