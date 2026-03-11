module ctrl(
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    output reg        ALUSrc,
    output reg        MemtoReg,
    output reg        RegWrite,
    output reg        MemWrite,
    output reg        Branch,
    output reg        Jump,
    output reg        is_lui,
    output reg  [2:0] ImmSel,
    output reg  [3:0] ALUCtrl
);

    // Opcode 定义
    localparam R_TYPE = 7'b0110011; // add, sub, and, or...
    localparam I_TYPE = 7'b0010011; // addi, andi, ori...
    localparam LOAD   = 7'b0000011; // lw
    localparam STORE  = 7'b0100011; // sw
    localparam BRANCH = 7'b1100011; // beq, bne...
    localparam JAL    = 7'b1101111; // jal
    localparam JALR   = 7'b1100111; // jalr
    localparam LUI    = 7'b0110111; // lui

    // ALUCtrl 编码：
    // 0000 ADD  0001 SUB  0010 SLL  0011 SLT  0100 SLTU
    // 0101 XOR  0110 SRL  0111 SRA  1000 OR   1001 AND
    always @(*) begin
        // 赋予默认值
        ALUSrc   = 1'b0;
        MemtoReg = 1'b0;
        RegWrite = 1'b0;
        MemWrite = 1'b0;
        Branch   = 1'b0;
        Jump     = 1'b0;
        is_lui   = 1'b0;
        ImmSel   = 3'b000;
        ALUCtrl  = 4'b0000; // 默认加法

        case (opcode)
            R_TYPE: begin
                RegWrite = 1'b1;
                case (funct3)
                    3'b000: ALUCtrl = (funct7 == 7'b0100000) ? 4'b0001 : 4'b0000; // SUB/ADD
                    3'b001: ALUCtrl = 4'b0010; // SLL
                    3'b010: ALUCtrl = 4'b0011; // SLT
                    3'b011: ALUCtrl = 4'b0100; // SLTU
                    3'b100: ALUCtrl = 4'b0101; // XOR
                    3'b101: ALUCtrl = (funct7 == 7'b0100000) ? 4'b0111 : 4'b0110; // SRA/SRL
                    3'b110: ALUCtrl = 4'b1000; // OR
                    3'b111: ALUCtrl = 4'b1001; // AND
                    default: ALUCtrl = 4'b0000;
                endcase
            end
            
            I_TYPE: begin
                ALUSrc   = 1'b1;
                RegWrite = 1'b1;
                ImmSel   = 3'b000; // I-Type
                case (funct3)
                    3'b000: ALUCtrl = 4'b0000; // ADDI
                    3'b001: ALUCtrl = 4'b0010; // SLLI
                    3'b010: ALUCtrl = 4'b0011; // SLTI
                    3'b011: ALUCtrl = 4'b0100; // SLTIU
                    3'b100: ALUCtrl = 4'b0101; // XORI
                    3'b101: ALUCtrl = (funct7 == 7'b0100000) ? 4'b0111 : 4'b0110; // SRAI/SRLI
                    3'b110: ALUCtrl = 4'b1000; // ORI
                    3'b111: ALUCtrl = 4'b1001; // ANDI
                    default: ALUCtrl = 4'b0000;
                endcase
            end
            
            LOAD: begin
                ALUSrc   = 1'b1;
                MemtoReg = 1'b1;
                RegWrite = 1'b1;
                ImmSel   = 3'b000; // I-Type 立即数用于地址计算
                ALUCtrl  = 4'b0000; // ADD
            end
            
            STORE: begin
                ALUSrc   = 1'b1;
                MemWrite = 1'b1;
                ImmSel   = 3'b001; // S-Type
                ALUCtrl  = 4'b0000; // ADD
            end
            
            BRANCH: begin
                Branch   = 1'b1;
                ImmSel   = 3'b010; // B-Type
                ALUCtrl  = 4'b0001; // SUB (用减法结果判断是否相等/大小)
            end
            
            JAL: begin
                Jump     = 1'b1;
                RegWrite = 1'b1;
                ImmSel   = 3'b011; // J-Type
            end
            
            JALR: begin
                Jump     = 1'b1;
                RegWrite = 1'b1;
                ALUSrc   = 1'b1;
                ImmSel   = 3'b000; // I-Type
                ALUCtrl  = 4'b0000; // ADD
            end
            
            LUI: begin
                RegWrite = 1'b1;
                is_lui   = 1'b1;
                ImmSel   = 3'b100; // U-Type
                ALUCtrl  = 4'b0000; // ALU 可以直接做加法 (与0相加)
            end
            
            default: ; // 保持默认值
        endcase
    end
endmodule