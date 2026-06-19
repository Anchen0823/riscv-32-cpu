# fib_keyboard_input.asm
#
# 功能：主程序空转；每次 PS/2 键盘中断在 0x100 取一个 ASCII，拼十进制 n，
#       回车 (CR/LF) 后计算 fib(n) 写七段管 (0xffff000c)，并清零 n 准备下一行。
#
# 与 SCPU / fpga_top 约定：
#   中断向量固定 0x00000100（见 SCPU.v take_interrupt）。
#   0xffff0010  KBD_DATA
#   0xffff0014  KBD_STATUS  bit0=ready；sw 且 data[0]=1 清 ready
#   0xffff0018  IRQ_RET     sw 且 data[0]=1 从中断返回（恢复 EPC）
#   0xffff000c  SEG7_DATA
#
# 无硬件自动压栈：x31(I/O 基址)、x1(栈)、x11(当前输入的 n) 由 main 初始化后在
# 主程序与 ISR 间持久保留；fib 仍用 x1 作栈，勿在中断外再改 x1。
#
# 非数字、非回车：忽略，仍清键盘并 IRQ_RET，避免 irq 一直拉高。
#
# 若用 GNU as 汇编：.fill 行依赖 main+idle 共 16 字节；若改动前面指令条数，
# 请改为 .fill ((0x100 - .) >> 2), 4, 0x00000013 使 irq_handler 落在 0x100。

	lui	x31, 0xFFFF0
	addi	x1, x0, -4
	addi	x11, x0, 0

idle:
	jal	x0, idle

	# 填充 nop 至 0x100（与 imem 字对齐）
	.fill	((0x100 - .) >> 2), 4, 0x00000013

irq_handler:
	lui	x31, 0xFFFF0
	lw	x10, 0x010(x31)
	addi	x12, x0, 1
	sw	x12, 0x014(x31)

	addi	x12, x0, 0x0D
	beq	x10, x12, on_enter
	addi	x12, x0, 0x0A
	beq	x10, x12, on_enter

	addi	x12, x0, 0x30
	blt	x10, x12, irq_exit
	addi	x13, x0, 0x39
	blt	x13, x10, irq_exit

	addi	x14, x10, -0x30
	slli	x12, x11, 3
	slli	x13, x11, 1
	add	x12, x12, x13
	add	x12, x12, x14
	addi	x13, x0, 32
	sltu	x15, x12, x13
	beq	x15, x0, cap_irq
	add	x11, x12, x0
	jal	x0, irq_exit
cap_irq:
	addi	x11, x0, 31
	jal	x0, irq_exit

on_enter:
	add	x6, x11, x0
	jal	x5, fib
	sw	x7, 0x00C(x31)
	addi	x11, x0, 0
	jal	x0, irq_exit

irq_exit:
	addi	x12, x0, 1
	sw	x12, 0x018(x31)
irq_done:
	jal	x0, irq_done

# ---------- fib(n)，与 fibonacci.asm 相同 ----------
fib:
	addi	x7, x0, 1
	bge	x7, x6, ret
	addi	x1, x1, -8
	sw	x5, 4(x1)
	addi	x6, x6, -1
	jal	x5, fib
	sw	x7, 0(x1)
	addi	x6, x6, -1
	jal	x5, fib
	lw	x8, 0(x1)
	add	x7, x7, x8
	addi	x6, x6, 2
	lw	x5, 4(x1)
	addi	x1, x1, 8
ret:
	jalr	x0, x5, 0
