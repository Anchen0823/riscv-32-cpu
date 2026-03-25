module dm(
    input         clk,
    input         DMWr,       // 写使能
    input  [6:0]  addr,       // 字地址，对应 Addr[8:2]
    input  [1:0]  word_off,   // 字内字节偏移 Addr[1:0]
    input  [2:0]  st_funct3,  // 写类型：SB=000, SH=001, SW=010（仅在 DMWr 时有效）
    input  [31:0] din,        // rs2 原始值；SB 用 [7:0]，SH 用 [15:0]，SW 用全字
    output [31:0] dout        // 读出的整字（LB 等由 CPU 截取）
);
    reg [31:0] RAM [0:127];

    // RHS 的 RAM[addr] 为写前旧值（非阻塞赋值语义）
    always @(posedge clk) begin
        if (DMWr) begin
            case (st_funct3)
                3'b010: RAM[addr] <= din; // SW
                3'b000: begin // SB
                    case (word_off)
                        2'b00: RAM[addr] <= {RAM[addr][31:8],  din[7:0]};
                        2'b01: RAM[addr] <= {RAM[addr][31:16], din[7:0], RAM[addr][7:0]};
                        2'b10: RAM[addr] <= {RAM[addr][31:24], din[7:0], RAM[addr][15:0]};
                        2'b11: RAM[addr] <= {din[7:0], RAM[addr][23:0]};
                    endcase
                end
                3'b001: begin // SH
                    case (word_off[1])
                        1'b0: RAM[addr] <= {RAM[addr][31:16], din[15:0]};
                        1'b1: RAM[addr] <= {din[15:0], RAM[addr][15:0]};
                    endcase
                end
                default: RAM[addr] <= din;
            endcase
        end
    end

    assign dout = RAM[addr];
endmodule
