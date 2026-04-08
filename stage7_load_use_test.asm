# Stage-7 test: 通用 load-use hazard 检测 + 停顿
# 目标：覆盖 lw 后紧邻使用 rs1/rs2 的场景（ALU/STORE/BRANCH）
#
# 结果约定：
# - 全部通过：x30 = 6, x31 = 7
# - 失败：x31 = 失败用例编号（1~6），或 15（最终汇总失败）

main:
        addi    x30, x0, 0          # pass counter
        addi    x31, x0, 0          # status code
        addi    x1,  x0, 0          # base addr = 0

        addi    x2,  x0, 5
        addi    x3,  x0, 20
        addi    x4,  x0, 123
        addi    x5,  x0, 77
        addi    x7,  x0, 9
        addi    x8,  x0, 14

        # memory init
        sw      x4,  0(x1)          # mem[0]  = 123
        sw      x2,  4(x1)          # mem[4]  = 5
        sw      x3,  8(x1)          # mem[8]  = 20
        sw      x5, 12(x1)          # mem[12] = 77
        sw      x7, 16(x1)          # mem[16] = 9
        sw      x8, 20(x1)          # mem[20] = 14

        # ------------------------------------------------------------
        # Case1: load -> ALU (rs1)
        # lw x10 后紧邻 add 使用 x10
        # ------------------------------------------------------------
        lw      x10, 4(x1)          # x10 = 5
        add     x11, x10, x2        # x11 = 10
        addi    x12, x0, 10
        bne     x11, x12, fail1
        addi    x30, x30, 1

        # ------------------------------------------------------------
        # Case2: load -> ALU (rs2)
        # lw x13 后紧邻 sub 使用 x13 作为 rs2
        # ------------------------------------------------------------
        lw      x13, 8(x1)          # x13 = 20
        sub     x14, x3, x13        # x14 = 0
        bne     x14, x0, fail2
        addi    x30, x30, 1

        # ------------------------------------------------------------
        # Case3: load -> store data (rs2)
        # lw x15 后紧邻 sw x15
        # ------------------------------------------------------------
        lw      x15, 12(x1)         # x15 = 77
        sw      x15, 24(x1)         # mem[24] = 77
        lw      x16, 24(x1)         # x16 = 77
        bne     x16, x5, fail3
        addi    x30, x30, 1

        # ------------------------------------------------------------
        # Case4: load -> branch compare (rs1)
        # lw x17 后紧邻 beq x17, x7
        # ------------------------------------------------------------
        lw      x17, 16(x1)         # x17 = 9
        beq     x17, x7, c4_ok
        jal     x0, fail4
c4_ok:
        addi    x30, x30, 1

        # ------------------------------------------------------------
        # Case5: load -> branch compare (rs2)
        # lw x18 后紧邻 beq x8, x18
        # ------------------------------------------------------------
        lw      x18, 20(x1)         # x18 = 14
        beq     x8,  x18, c5_ok
        jal     x0, fail5
c5_ok:
        addi    x30, x30, 1

        # ------------------------------------------------------------
        # Case6: load -> ALU -> branch
        # 先验证 load-use，再验证后续结果可被正确比较
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
