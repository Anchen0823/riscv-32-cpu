`include "definition.vh"

module SCPU(
    input         clk,
    input         reset,
    input  [31:0] inst_in,    // 来自指令存储器
    input  [31:0] Data_in,    // 来自数据存储器
    output        mem_w,      // 访存写信号
    output [31:0] PC_out,     // 指令地址
    output [31:0] Addr_out,   // 访存地址
    output [31:0] Data_out,   // 访存写入数据
    input  [4:0]  reg_sel,    // 调试用
    output [31:0] reg_data    // 调试用
);

    // ============================================================
    // --- 信号定义与握手逻辑 ---
    // ============================================================
    wire if_allowin, id_allowin, ex_allowin, mem_allowin, wb_allowin;
    wire if_ready_go, id_ready_go, ex_ready_go, mem_ready_go, wb_ready_go;
    wire if_to_id_valid, id_to_ex_valid, ex_to_mem_valid, mem_to_wb_valid;

    // 现阶段所有 ready_go 恒为 1
    assign {if_ready_go, id_ready_go, ex_ready_go, mem_ready_go, wb_ready_go} = 5'b11111;

    // 握手链
    assign if_allowin  = (if_ready_go && id_allowin); 
    assign id_allowin  = !id_valid  || (id_ready_go  && ex_allowin);
    assign ex_allowin  = !ex_valid  || (ex_ready_go  && mem_allowin);
    assign mem_allowin = !mem_valid || (mem_ready_go && wb_allowin);
    assign wb_allowin  = !wb_valid  || (wb_ready_go  && 1'b1); // 最后一级

    // ============================================================
    // --- 1. IF Stage (取指) ---
    // ============================================================
    reg  [31:0] if_pc;
    wire [31:0] next_pc;
    
    // PC 寄存器
    always @(posedge clk or posedge reset) begin
        if (reset) if_pc <= 32'h0;
        else if (if_allowin) if_pc <= next_pc; // 简单框架下暂不考虑跳转导致的冲刷
    end
    assign PC_out = if_pc;
    assign if_to_id_valid = !reset; // 简单假设 IF 始终有效

    // ============================================================
    // --- 2. ID Stage (译码/读寄存器) ---
    // ============================================================
    reg         id_valid;
    reg  [31:0] id_pc, id_inst;

    // IF/ID 流水线寄存器
    always @(posedge clk) begin
        if (reset) id_valid <= 1'b0;
        else if (id_allowin) id_valid <= if_to_id_valid;
        if (id_allowin && if_to_id_valid) begin
            id_pc   <= if_pc;
            id_inst <= inst_in;
        end
    end

    // 译码与寄存器读取逻辑
    wire [2:0] id_imm_sel, id_alu_ctrl;
    wire id_alu_src, id_mem_to_reg, id_reg_write, id_mem_write, id_is_lui, id_jump, id_branch;
    
    ctrl U_CTRL (
        .opcode(id_inst[6:0]), .funct3(id_inst[14:12]), .funct7(id_inst[31:25]),
        .ALUSrc(id_alu_src), .MemtoReg(id_mem_to_reg), .RegWrite(id_reg_write),
        .MemWrite(id_mem_write), .Branch(id_branch), .Jump(id_jump),
        .is_lui(id_is_lui), .ImmSel(id_imm_sel), .ALUCtrl(id_alu_ctrl)
    );

    // 立即数生成 (ImmGen)
    reg [31:0] id_ext_imm;
    always @(*) begin
        case(id_imm_sel)
            3'b000: id_ext_imm = {{20{id_inst[31]}}, id_inst[31:20]};                                   // I-Type
            3'b001: id_ext_imm = {{20{id_inst[31]}}, id_inst[31:25], id_inst[11:7]};                    // S-Type
            3'b010: id_ext_imm = {{20{id_inst[31]}}, id_inst[7], id_inst[30:25], id_inst[11:8], 1'b0};  // B-Type
            3'b011: id_ext_imm = {{12{id_inst[31]}}, id_inst[19:12], id_inst[20], id_inst[30:21], 1'b0};// J-Type
            3'b100: id_ext_imm = {id_inst[31:12], 12'b0};                                               // U-Type
            default: id_ext_imm = 32'b0;
        endcase
    end

    wire [31:0] rdata1, rdata2;
    // RF 写回数据在 WB 阶段，此处仅读取
    RF U_RF (
        .clk(clk), .rst(reset), .R1_adr(id_inst[19:15]), .R2_adr(id_inst[24:20]),
        .W_adr(wb_rd), .Din(wb_write_data), .We(wb_reg_write), // 来自 WB 阶段
        .R1_dat(rdata1), .R2_dat(rdata2), .reg_sel(reg_sel), .reg_data(reg_data)
    );

    assign id_to_ex_valid = id_valid && id_ready_go;

    // ============================================================
    // --- 3. EX Stage (执行) ---
    // ============================================================
    reg         ex_valid;
    reg  [31:0] ex_rdata1, ex_rdata2, ex_imm, ex_pc;
    reg  [4:0]  ex_rd;
    reg         ex_alu_src, ex_mem_to_reg, ex_reg_write, ex_mem_write, ex_is_lui;
    reg  [2:0]  ex_alu_ctrl;

    // ID/EX 流水线寄存器
    always @(posedge clk) begin
        if (reset) ex_valid <= 1'b0;
        else if (ex_allowin) ex_valid <= id_to_ex_valid;
        if (ex_allowin && id_to_ex_valid) begin
            {ex_rdata1, ex_rdata2, ex_imm, ex_pc} <= {rdata1, rdata2, id_ext_imm, id_pc};
            ex_rd <= id_inst[11:7];
            {ex_alu_src, ex_mem_to_reg, ex_reg_write, ex_mem_write, ex_is_lui, ex_alu_ctrl} <= 
            {id_alu_src, id_mem_to_reg, id_reg_write, id_mem_write, id_is_lui, id_alu_ctrl};
        end
    end

    wire [31:0] alu_A = ex_is_lui ? 32'b0 : ex_rdata1;
    wire [31:0] alu_B = ex_alu_src ? ex_imm : ex_rdata2;
    wire [31:0] ex_alu_result;

    alu U_ALU (.A(alu_A), .B(alu_B), .ALUOp(ex_alu_ctrl), .C(ex_alu_result));
    
    assign ex_to_mem_valid = ex_valid && ex_ready_go;

    // ============================================================
    // --- 4. MEM Stage (访存) ---
    // ============================================================
    reg         mem_valid;
    reg  [31:0] mem_alu_result, mem_write_data;
    reg  [4:0]  mem_rd;
    reg         mem_mem_to_reg, mem_reg_write, mem_mem_write;

    // EX/MEM 流水线寄存器
    always @(posedge clk) begin
        if (reset) mem_valid <= 1'b0;
        else if (mem_allowin) mem_valid <= ex_to_mem_valid;
        if (mem_allowin && ex_to_mem_valid) begin
            mem_alu_result <= ex_alu_result;
            mem_write_data <= ex_rdata2;
            mem_rd <= ex_rd;
            {mem_mem_to_reg, mem_reg_write, mem_mem_write} <= {ex_mem_to_reg, ex_reg_write, ex_mem_write};
        end
    end

    assign Addr_out = mem_alu_result;
    assign Data_out = mem_write_data;
    assign mem_w    = mem_mem_write && mem_valid; // 只有有效指令才能写内存

    assign mem_to_wb_valid = mem_valid && mem_ready_go;

    // ============================================================
    // --- 5. WB Stage (写回) ---
    // ============================================================
    reg         wb_valid;
    reg  [31:0] wb_alu_result, wb_mem_data;
    reg  [4:0]  wb_rd;
    reg         wb_mem_to_reg, wb_reg_write;

    // MEM/WB 流水线寄存器
    always @(posedge clk) begin
        if (reset) wb_valid <= 1'b0;
        else if (wb_allowin) wb_valid <= mem_to_wb_valid;
        if (wb_allowin && mem_to_wb_valid) begin
            wb_alu_result <= mem_alu_result;
            wb_mem_data   <= Data_in;
            wb_rd <= mem_rd;
            {wb_mem_to_reg, wb_reg_write} <= {mem_mem_to_reg, mem_reg_write};
        end
    end

    wire [31:0] wb_write_data = wb_mem_to_reg ? wb_mem_data : wb_alu_result;
    
    // PC 更新逻辑 (简单实现：假设无阻塞)
    assign next_pc = if_pc + 4; 

endmodule