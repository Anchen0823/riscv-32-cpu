# =============================================================================
# cpu_test_safe.asm — 无冒险 RISC-V 测试（5 级流水线、无停顿/无转发）
#
# 间隔：每条「写 rd」后到「读该 rd」之间插入 3 条 NOP（addi x0,x0,0）。
#       Store 后对同一字地址 Load 同样插入 3 条 NOP。
#       IM 仅 128 字（512 字节），本程序保持简短。
#       DM 字索引 = Addr[8:2]，字节地址须在 0x000～0x1FC（例：0x100 → 索引 64）。
#
#   riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 cpu_test_safe.asm -o cpu_test_safe.o
#   riscv64-unknown-elf-ld -Ttext 0x0 cpu_test_safe.o -o cpu_test_safe.elf
#   riscv64-unknown-elf-objcopy -O verilog cpu_test_safe.elf Test_8_Instr.dat
# =============================================================================

    .text
    .globl _start
    .align 2

_start:
    # --- I-type：addi / andi / ori ---
    addi    x1, x0, 5
    addi    x0, x0, 0
    addi    x0, x0, 0
    addi    x0, x0, 0

    addi    x2, x0, 3
    addi    x0, x0, 0
    addi    x0, x0, 0
    addi    x0, x0, 0

    andi    x4, x1, 7
    addi    x0, x0, 0
    addi    x0, x0, 0
    addi    x0, x0, 0

    ori     x6, x1, 0x100
    addi    x0, x0, 0
    addi    x0, x0, 0
    addi    x0, x0, 0

    # --- R-type：add / sub / xor ---
    add     x8, x1, x2
    addi    x0, x0, 0
    addi    x0, x0, 0
    addi    x0, x0, 0

    sub     x9, x8, x2
    addi    x0, x0, 0
    addi    x0, x0, 0
    addi    x0, x0, 0

    xor     x12, x8, x1
    addi    x0, x0, 0
    addi    x0, x0, 0
    addi    x0, x0, 0

    # --- U-type：基址；auipc ---
    addi    x20, x0, 0x100
    addi    x0, x0, 0
    addi    x0, x0, 0
    addi    x0, x0, 0

    auipc   x21, 0
    addi    x0, x0, 0
    addi    x0, x0, 0
    addi    x0, x0, 0

    # --- lui + addi 得到 0xA5A5A5A5，再 sw / lw ---
    lui     x13, 0xA5A5A
    addi    x0, x0, 0
    addi    x0, x0, 0
    addi    x0, x0, 0

    addi    x13, x13, 0x5A5
    addi    x0, x0, 0
    addi    x0, x0, 0
    addi    x0, x0, 0

    sw      x13, 0(x20)
    addi    x0, x0, 0
    addi    x0, x0, 0
    addi    x0, x0, 0

    lw      x14, 0(x20)
    addi    x0, x0, 0
    addi    x0, x0, 0
    addi    x0, x0, 0

    # --- BEQ 跳转 ---
    addi    x15, x0, 0x11
    addi    x0, x0, 0
    addi    x0, x0, 0
    addi    x0, x0, 0

    addi    x16, x0, 0x11
    addi    x0, x0, 0
    addi    x0, x0, 0
    addi    x0, x0, 0

    beq     x15, x16, skip_beq_dead
    addi    x17, x0, 0x7ED
skip_beq_dead:
    # --- BNE 不跳转（x18 == x19）---
    addi    x18, x0, 0x22
    addi    x0, x0, 0
    addi    x0, x0, 0
    addi    x0, x0, 0

    addi    x19, x0, 0x22
    addi    x0, x0, 0
    addi    x0, x0, 0
    addi    x0, x0, 0

    bne     x18, x19, bne_bad
    addi    x0, x0, 0
    addi    x0, x0, 0
    addi    x0, x0, 0
    addi    x22, x0, 0x44

    addi    x0, x0, 0
    addi    x0, x0, 0
    addi    x0, x0, 0

    # --- JAL / JALR ---
    jal     x5, jal_sub
    addi    x0, x0, 0
    addi    x0, x0, 0
    addi    x0, x0, 0

    addi    x23, x0, 0x55
    addi    x0, x0, 0
    addi    x0, x0, 0
    addi    x0, x0, 0

    j       test_end

bne_bad:
    addi    x24, x0, 0x7AD
    j       test_end

jal_sub:
    addi    x25, x0, 0x66
    addi    x0, x0, 0
    addi    x0, x0, 0
    addi    x0, x0, 0
    jalr    x0, x5, 0

test_end:
    j       test_end
