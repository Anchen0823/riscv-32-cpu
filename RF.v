module RF(
    input  wire        clk,
    input  wire        rst,
    input  wire [4:0]  R1_adr,    
    input  wire [4:0]  R2_adr,    
    input  wire [4:0]  W_adr,     
    input  wire [31:0] Din,       
    input  wire        We,        
    output wire [31:0] R1_dat,    
    output wire [31:0] R2_dat,    
    input  wire [4:0]  reg_sel,   
    output wire [31:0] reg_data   
);

    reg [31:0] rf [0:31];
    integer i;

    // 写操作
    // 采用“上半拍写回、下半拍读出”的等效实现：
    // 流水线级间寄存在 posedge 更新，寄存器堆在 negedge 写入，
    // 使下一拍 ID 在 posedge 锁存操作数时可见到最新写回值。
    always @(negedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1) begin
                rf[i] <= 32'b0;
            end
        end else if (We && (W_adr != 5'b0)) begin
            rf[W_adr] <= Din;
        end
    end

    // 读操作
    assign R1_dat   = (R1_adr == 5'b0)  ? 32'b0 : rf[R1_adr];
    assign R2_dat   = (R2_adr == 5'b0)  ? 32'b0 : rf[R2_adr];
    
    // 调试端口
    assign reg_data = (reg_sel == 5'b0) ? 32'b0 : rf[reg_sel];

endmodule