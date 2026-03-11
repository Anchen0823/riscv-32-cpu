module alu(A,B,ALUOp,C);
    input [31:0] A,B;
    input [3:0] ALUOp;
    output reg [31:0] C;
    always @(*) begin
        case (ALUOp)
            4'b0000: C = A + B;                       // ADD
            4'b0001: C = A - B;                       // SUB
            4'b0010: C = A << B[4:0];                 // SLL
            4'b0011: C = ($signed(A) < $signed(B));   // SLT
            4'b0100: C = (A < B);                     // SLTU
            4'b0101: C = A ^ B;                       // XOR
            4'b0110: C = A >> B[4:0];                 // SRL
            4'b0111: C = $signed(A) >>> B[4:0];       // SRA
            4'b1000: C = A | B;                       // OR
            4'b1001: C = A & B;                       // AND
            default: C = 32'b0;
        endcase
    end
endmodule