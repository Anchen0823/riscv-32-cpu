module im(
    input  [8:0]  addr,    // 对应 PC[10:2]，支持 512 个字 (2048 字节)
    output [31:0] dout
);
    reg [31:0] ROM [0:511]; // 内部存储数组

    // 测试台会通过 U_SCCOMP.U_IM.ROM 路径用 $readmemh 把 Test_8_Instr.dat 读进来
    assign dout = ROM[addr];
endmodule