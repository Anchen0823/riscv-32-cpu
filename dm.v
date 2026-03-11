module dm(
    input         clk,
    input         DMWr,    // 写使能
    input  [6:0]  addr,    // 对应 dm_addr
    input  [31:0] din,     // 写入的数据
    output [31:0] dout     // 读出的数据
);
    reg [31:0] RAM [0:127]; // 内部存储数组

    always @(posedge clk) begin
        if (DMWr) begin
            RAM[addr] <= din;
        end
    end

    assign dout = RAM[addr];
endmodule