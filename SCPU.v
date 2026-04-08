`include "definition.vh"

module SCPU(
    input         clk,
    input         reset,
    input  [31:0] inst_in,    // 来自指令存储器
    input  [31:0] Data_in,    // 来自数据存储器
    output        mem_w,      // 访存写信号
    output [31:0] PC_out,     // 指令地址
    output [31:0] Addr_out,   // 访存地址
    output [31:0] Data_out,   // 访存写入数据（rs2 原始值，SB/SH 合并由 dm 完成）
    output [1:0]  dm_word_off,// 字内字节偏移，接 Addr_out[1:0]
    output [2:0]  dm_funct3,  // MEM 段 funct3，写内存时 dm 用其区分 SB/SH/SW
    input  [4:0]  reg_sel,    // 调试用
    output [31:0] reg_data    // 调试用
);


    // --- 信号定义与握手逻辑 ---
    wire if_allowin, id_allowin, ex_allowin, mem_allowin, wb_allowin;
    wire if_ready_go, id_ready_go, ex_ready_go, mem_ready_go, wb_ready_go;
    wire if_to_id_valid, id_to_ex_valid, ex_to_mem_valid, mem_to_wb_valid;

    // 除了 ID 级可能因分支相关 load-use 冲突停顿，其余级 ready_go 恒为 1
    assign if_ready_go  = 1'b1;
    assign ex_ready_go  = 1'b1;
    assign mem_ready_go = 1'b1;
    assign wb_ready_go  = 1'b1;

    // 握手链
    assign if_allowin  = (if_ready_go && id_allowin); 
    assign id_allowin  = !id_valid  || (id_ready_go  && ex_allowin);
    assign ex_allowin  = !ex_valid  || (ex_ready_go  && mem_allowin);
    assign mem_allowin = !mem_valid || (mem_ready_go && wb_allowin);
    assign wb_allowin  = !wb_valid  || (wb_ready_go  && 1'b1); // 最后一级


    // --- 1. IF Stage ---
    reg  [31:0] if_pc;
    wire [31:0] next_pc;
    
    // PC 寄存器
    always @(posedge clk or posedge reset) begin
        if (reset) if_pc <= 32'h0;
        else if (if_allowin) if_pc <= next_pc; // 暂不考虑跳转导致的冲刷
    end
    assign PC_out = if_pc;
    assign if_to_id_valid = !reset;


    // --- 2. ID Stage  ---
    reg         id_valid;
    reg  [31:0] id_pc, id_inst;

    // IF/ID 流水线寄存器
    always @(posedge clk or posedge reset) begin
        if (reset) id_valid <= 1'b0;
        else if (id_allowin) id_valid <= if_to_id_valid && !id_redirect;
        if (id_allowin && if_to_id_valid && !id_redirect) begin
            id_pc   <= if_pc;
            id_inst <= inst_in;
        end
    end

    // 译码与寄存器读取逻辑
    wire [2:0] id_imm_sel;
    wire [2:0] id_funct3;
    wire [3:0] id_alu_ctrl;
    wire id_alu_src, id_mem_to_reg, id_reg_write, id_mem_write, id_is_lui, id_is_auipc, id_jump, id_branch;
    
    ctrl U_CTRL (
        .opcode(id_inst[6:0]), .funct3(id_inst[14:12]), .funct7(id_inst[31:25]),
        .ALUSrc(id_alu_src), .MemtoReg(id_mem_to_reg), .RegWrite(id_reg_write),
        .MemWrite(id_mem_write), .Branch(id_branch), .Jump(id_jump),
        .is_lui(id_is_lui), .is_auipc(id_is_auipc), .ImmSel(id_imm_sel), .ALUCtrl(id_alu_ctrl)
    );
    assign id_funct3 = id_inst[14:12];

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
    // RF 读取
    RF U_RF (
        .clk(clk), .rst(reset), .R1_adr(id_inst[19:15]), .R2_adr(id_inst[24:20]),
        .W_adr(wb_rd), .Din(wb_write_data), .We(wb_reg_write), // 来自 WB 阶段
        .R1_dat(rdata1), .R2_dat(rdata2), .reg_sel(reg_sel), .reg_data(reg_data)
    );

    // ===== 阶段 6：ID 级分支/跳转前递 + 冲突检测 =====
    wire [4:0] id_rs1 = id_inst[19:15];
    wire [4:0] id_rs2 = id_inst[24:20];
    wire id_is_jalr   = (id_inst[6:0] == 7'b1100111);

    // EX 级可前递数据（load 指令在 EX 级数据尚未可用，不能前递）
    wire [31:0] ex_forward_data  = ex_jump ? (ex_pc + 32'd4) : ex_alu_result_raw;
    wire ex_can_forward_to_id    = ex_valid && ex_reg_write && !ex_mem_to_reg && (ex_rd != 5'd0);
    wire mem_can_forward_to_id   = mem_valid && mem_reg_write && (mem_rd != 5'd0);
    wire wb_can_forward_to_id    = wb_valid && wb_reg_write && (wb_rd != 5'd0);

    wire [31:0] id_branch_src1 = (ex_can_forward_to_id  && (ex_rd  == id_rs1)) ? ex_forward_data :
                                 (mem_can_forward_to_id && (mem_rd == id_rs1)) ? (mem_mem_to_reg ? mem_load_data : mem_alu_result) :
                                 (wb_can_forward_to_id  && (wb_rd  == id_rs1)) ? wb_write_data : rdata1;

    wire [31:0] id_branch_src2 = (ex_can_forward_to_id  && (ex_rd  == id_rs2)) ? ex_forward_data :
                                 (mem_can_forward_to_id && (mem_rd == id_rs2)) ? (mem_mem_to_reg ? mem_load_data : mem_alu_result) :
                                 (wb_can_forward_to_id  && (wb_rd  == id_rs2)) ? wb_write_data : rdata2;

    // 仅在 branch/jalr 需要源操作数时，检测 EX 级 load-use 冲突并停顿 1 拍
    wire id_need_rs1 = id_branch || id_is_jalr;
    wire id_need_rs2 = id_branch;
    wire id_branch_load_hazard = id_valid && ex_valid && ex_mem_to_reg && (ex_rd != 5'd0) &&
                                 ((id_need_rs1 && (ex_rd == id_rs1)) || (id_need_rs2 && (ex_rd == id_rs2)));
    assign id_ready_go = !id_branch_load_hazard;

    // 分支/跳转判断与目标地址计算（使用前递后的操作数）
    wire id_beq_taken  = (id_branch_src1 == id_branch_src2);
    wire id_bne_taken  = (id_branch_src1 != id_branch_src2);
    wire id_blt_taken  = ($signed(id_branch_src1) < $signed(id_branch_src2));
    wire id_bge_taken  = ($signed(id_branch_src1) >= $signed(id_branch_src2));
    wire id_bltu_taken = (id_branch_src1 < id_branch_src2);
    wire id_bgeu_taken = (id_branch_src1 >= id_branch_src2);

    reg id_branch_taken;
    always @(*) begin
        case (id_inst[14:12])
            3'b000: id_branch_taken = id_beq_taken;   // BEQ
            3'b001: id_branch_taken = id_bne_taken;   // BNE
            3'b100: id_branch_taken = id_blt_taken;   // BLT
            3'b101: id_branch_taken = id_bge_taken;   // BGE
            3'b110: id_branch_taken = id_bltu_taken;  // BLTU
            3'b111: id_branch_taken = id_bgeu_taken;  // BGEU
            default: id_branch_taken = 1'b0;
        endcase
    end

    wire [31:0] id_branch_target = id_pc + id_ext_imm;
    wire [31:0] id_jalr_target   = (id_branch_src1 + id_ext_imm) & 32'hffff_fffe;
    wire id_redirect = id_valid && !id_branch_load_hazard && (id_jump || (id_branch && id_branch_taken));

    assign id_to_ex_valid = id_valid && id_ready_go;


    // --- 3. EX Stage  ---
    reg         ex_valid;
    reg  [31:0] ex_rdata1, ex_rdata2, ex_imm, ex_pc;
    reg  [4:0]  ex_rd;
    reg         ex_alu_src, ex_mem_to_reg, ex_reg_write, ex_mem_write, ex_is_lui, ex_is_auipc, ex_jump;
    reg  [2:0]  ex_funct3;
    reg  [3:0]  ex_alu_ctrl;

    // ID/EX 流水线寄存器
    always @(posedge clk or posedge reset) begin
        if (reset) ex_valid <= 1'b0;
        else if (ex_allowin) ex_valid <= id_to_ex_valid;
        if (ex_allowin && id_to_ex_valid) begin
            {ex_rdata1, ex_rdata2, ex_imm, ex_pc} <= {rdata1, rdata2, id_ext_imm, id_pc};
            ex_rd <= id_inst[11:7];
            {ex_alu_src, ex_mem_to_reg, ex_reg_write, ex_mem_write, ex_is_lui, ex_is_auipc, ex_jump, ex_alu_ctrl} <= 
            {id_alu_src, id_mem_to_reg, id_reg_write, id_mem_write, id_is_lui, id_is_auipc, id_jump, id_alu_ctrl};
            ex_funct3 <= id_funct3;
        end
    end

    wire [31:0] alu_A = ex_is_lui ? 32'b0 : (ex_is_auipc ? ex_pc : ex_rdata1);
    wire [31:0] alu_B = ex_alu_src ? ex_imm : ex_rdata2;
    wire [31:0] ex_alu_result_raw;
    wire [31:0] ex_alu_result;

    alu U_ALU (.A(alu_A), .B(alu_B), .ALUOp(ex_alu_ctrl), .C(ex_alu_result_raw));
    assign ex_alu_result = ex_jump ? (ex_pc + 32'd4) : ex_alu_result_raw;
    
    assign ex_to_mem_valid = ex_valid && ex_ready_go;


    // --- 4. MEM Stage  ---
    reg         mem_valid;
    reg  [31:0] mem_alu_result, mem_write_data;
    reg  [4:0]  mem_rd;
    reg         mem_mem_to_reg, mem_reg_write, mem_mem_write;
    reg  [2:0]  mem_funct3;

    // EX/MEM 流水线寄存器
    always @(posedge clk or posedge reset) begin
        if (reset) mem_valid <= 1'b0;
        else if (mem_allowin) mem_valid <= ex_to_mem_valid;
        if (mem_allowin && ex_to_mem_valid) begin
            mem_alu_result <= ex_alu_result;
            mem_write_data <= ex_rdata2;
            mem_rd <= ex_rd;
            {mem_mem_to_reg, mem_reg_write, mem_mem_write} <= {ex_mem_to_reg, ex_reg_write, ex_mem_write};
            mem_funct3 <= ex_funct3;
        end
    end

    wire [1:0] mem_addr_off = mem_alu_result[1:0];
    reg  [31:0] mem_load_data;

    always @(*) begin
        case (mem_funct3)
            3'b000: begin // LB
                case (mem_addr_off)
                    2'b00: mem_load_data = {{24{Data_in[7]}},   Data_in[7:0]};
                    2'b01: mem_load_data = {{24{Data_in[15]}},  Data_in[15:8]};
                    2'b10: mem_load_data = {{24{Data_in[23]}},  Data_in[23:16]};
                    2'b11: mem_load_data = {{24{Data_in[31]}},  Data_in[31:24]};
                    default: mem_load_data = 32'b0;
                endcase
            end
            3'b001: begin // LH
                case (mem_addr_off[1])
                    1'b0: mem_load_data = {{16{Data_in[15]}}, Data_in[15:0]};
                    1'b1: mem_load_data = {{16{Data_in[31]}}, Data_in[31:16]};
                    default: mem_load_data = 32'b0;
                endcase
            end
            3'b010: mem_load_data = Data_in; // LW
            3'b100: begin // LBU
                case (mem_addr_off)
                    2'b00: mem_load_data = {24'b0, Data_in[7:0]};
                    2'b01: mem_load_data = {24'b0, Data_in[15:8]};
                    2'b10: mem_load_data = {24'b0, Data_in[23:16]};
                    2'b11: mem_load_data = {24'b0, Data_in[31:24]};
                    default: mem_load_data = 32'b0;
                endcase
            end
            3'b101: begin // LHU
                case (mem_addr_off[1])
                    1'b0: mem_load_data = {16'b0, Data_in[15:0]};
                    1'b1: mem_load_data = {16'b0, Data_in[31:16]};
                    default: mem_load_data = 32'b0;
                endcase
            end
            default: mem_load_data = Data_in;
        endcase
    end

    assign Addr_out     = mem_alu_result;
    assign Data_out     = mem_write_data;
    assign dm_word_off  = mem_alu_result[1:0];
    assign dm_funct3    = mem_funct3;
    assign mem_w        = mem_mem_write && mem_valid; // 只有有效指令才能写内存

    assign mem_to_wb_valid = mem_valid && mem_ready_go;


    // --- 5. WB Stage (写回) ---
    reg         wb_valid;
    reg  [31:0] wb_alu_result, wb_mem_data;
    reg  [4:0]  wb_rd;
    reg         wb_mem_to_reg, wb_reg_write;

    // MEM/WB 流水线寄存器
    always @(posedge clk or posedge reset) begin
        if (reset) wb_valid <= 1'b0;
        else if (wb_allowin) wb_valid <= mem_to_wb_valid;
        if (wb_allowin && mem_to_wb_valid) begin
            wb_alu_result <= mem_alu_result;
            wb_mem_data   <= mem_load_data;
            wb_rd <= mem_rd;
            {wb_mem_to_reg, wb_reg_write} <= {mem_mem_to_reg, mem_reg_write};
        end
    end

    wire [31:0] wb_write_data = wb_mem_to_reg ? wb_mem_data : wb_alu_result;
    
    // PC 更新逻辑：支持 branch/jal/jalr
    assign next_pc = id_redirect
                   ? (id_is_jalr ? id_jalr_target : id_branch_target)
                   : (if_pc + 32'd4);

endmodule