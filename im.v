module im(
    input  [7:0]  addr,    // 对应 PC[9:2]，支持 256 个字 (1024 字节)
    output [31:0] dout
);
    reg [31:0] ROM [0:255]; // 内部存储数组

    // 测试台会通过 U_SCCOMP.U_IM.ROM 路径用 $readmemh 把 Test_8_Instr.dat 读进来
    assign dout = ROM[addr];
endmodule