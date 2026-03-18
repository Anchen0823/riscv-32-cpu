# RISC-V 五级流水线 CPU

基于 Verilog 实现的 32 位 RISC-V 五级流水线 CPU（IF / ID / EX / MEM / WB），支持仿真与调试。

## 项目结构

| 文件 | 说明 |
|------|------|
| `SCPU.v` | 流水线 CPU 核（取指、译码、执行、访存、写回） |
| `ctrl.v` | 控制器（译码生成控制信号） |
| `alu.v` | 算术逻辑单元 |
| `RF.v` | 寄存器堆 |
| `im.v` | 指令存储器 |
| `dm.v` | 数据存储器 |
| `sccomp.v` | 顶层（CPU + IM + DM） |
| `sccomp_tb.v` | 仿真测试平台 |
| `Test_8_Instr.dat` | 测试程序（十六进制指令） |
| `run_sim.ps1` / `run_sim.bat` | 编译与运行仿真脚本 |

## 支持的指令

- **R 型**：ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU  
- **I 型（算术/逻辑）**：ADDI, ANDI, ORI, XORI, SLLI, SRLI, SRAI, SLTI, SLTIU  
- **访存**：LB, LH, LW, LBU, LHU, SB, SH, SW  
- **分支**：BEQ, BNE, BLT, BGE, BLTU, BGEU  
- **跳转**：JAL, JALR  
- **其他**：LUI  

## 环境与运行

- **仿真工具**：Icarus Verilog（`iverilog`、`vvp`）
- **仿真步骤**：
  1. 将测试程序写入 `Test_8_Instr.dat`（每行一条 32 位十六进制指令，可带 `//` 注释）
  2. 在项目根目录执行：
     - Windows：`.\run_sim.bat` 或 `powershell -ExecutionPolicy Bypass -File .\run_sim.ps1`
     - 或手动：`iverilog -o simv sccomp_tb.v sccomp.v SCPU.v ctrl.v alu.v RF.v im.v dm.v`，再 `vvp -n simv`
- **输出**：仿真会生成 `wave.vcd`（波形）和 `results.txt`（每拍 PC、指令、寄存器内容等，用于查看或比对）。

## 调试

- 在 testbench 中可通过 `reg_sel` 选择要观察的寄存器编号，`reg_data` 输出该寄存器的值；仿真时可将 `reg_sel` 与 `results.txt` 中的 `rf**` 对应查看。
