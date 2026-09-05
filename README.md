# RISC-V 五级流水线 CPU

基于 Verilog 实现的 32 位 RISC-V 五级流水线 CPU（IF / ID / EX / MEM / WB），支持仿真与调试。

课程设计仓库，包含 CPU 核、指令测试、FPGA 顶层、Vivado 工程及实验报告材料。支持范围见下方指令清单；现有仿真入口不等同于完整 RISC-V ISA 一致性认证。

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
| `Test_8_Instr.dat` | 综合测试（覆盖课程各阶段：LUI/AUIPC、I/R 型算术逻辑、分支与跳转、访存） |
| `run_sim.ps1` / `run_sim.bat` | 编译与运行仿真脚本 |

## 支持的指令

- **R 型**：ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU  
- **I 型（算术/逻辑）**：ADDI, ANDI, ORI, XORI, SLLI, SRLI, SRAI, SLTI, SLTIU  
- **访存**：LB, LH, LW, LBU, LHU, SB, SH, SW  
- **分支**：BEQ, BNE, BLT, BGE, BLTU, BGEU  
- **跳转**：JAL, JALR  
- **其他**：LUI、AUIPC（`pc + imm[31:12]<<12`）  

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

## 首次使用

```powershell
git clone https://github.com/Anchen0823/riscv-32-cpu.git
cd riscv-32-cpu
iverilog -V
vvp -V
powershell -NoProfile -ExecutionPolicy Bypass -File .\run_sim.ps1
```

`iverilog` 与 `vvp` 需要加入 PATH。手动编译和仿真应在仓库根目录执行，因为 testbench 按相对路径读取 `Test_8_Instr.dat`。

本次运行会写入 `simv`、`wave.vcd` 与 `results.txt`。仓库已有的波形和结果文件是历史产物，检查时应确认本次编译成功、输出文件更新，并对照预期寄存器值；当前脚本仅检查结果文件是否存在，没有自动判定每条指令是否正确。

## FPGA 与扩展资料

| 入口 | 内容 |
| --- | --- |
| [fpga_top.v](fpga_top.v) | FPGA 顶层 |
| [constrains/icf.xdc](constrains/icf.xdc) | 板卡引脚约束，沿用现有目录拼写 |
| [vivado/vivado.xpr](vivado/vivado.xpr) | Vivado 工程与存储器 IP 配置 |
| [coe](coe/) | 程序初始化文件 |
| [riscv测试代码](riscv测试代码/) | 汇编测试和机器码整理工具 |
| [阶段 9 计划](docs/stage9_interrupt_io_plan.md) | 键盘输入、中断和 I/O 扩展设计 |
| [WHUExperiment 模板](WHUExperiment-master/WHUExperiment-master/README.md) | 实验报告模板说明 |

上板前核对实际 FPGA 器件、引脚约束及 Vivado/IP 兼容性。阶段 9 文档属于扩展计划，不能作为键盘中断已经实现并通过上板验证的证据。
