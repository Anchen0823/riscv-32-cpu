`timescale 1ns / 1ps

module IP2SOC_Top(
    input         clk,
    input         rstn,
    input  [15:0] sw_i,
    output [7:0]  disp_seg_o,
    output [7:0]  disp_an_o
);

    wire        rst = ~rstn;
    wire        clk_cpu;
    wire [31:0] instr;
    wire [31:0] pc;
    wire        mem_write;
    wire [31:0] data_addr;
    wire [31:0] data_out;
    wire [31:0] data_in;
    wire [31:0] ram_dout;
    wire [1:0]  dm_word_off;
    wire [2:0]  dm_funct3;
    wire [31:0] reg_data;

    wire hit_switch = (data_addr == 32'hffff_0004);
    wire hit_seg7   = (data_addr == 32'hffff_000c);
    wire ram_write  = mem_write && !hit_switch && !hit_seg7;

    reg [31:0] seg7_latched;
    reg [31:0] display_data;

    CLK_DIV U_CLK_DIV(
        .clk(clk),
        .rst(rst),
        .SW15(sw_i[15]),
        .Clk_CPU(clk_cpu)
    );

    imem U_IMEM(
        .a(pc[8:2]),
        .spo(instr)
    );

    SCPU U_SCPU(
        .clk(clk_cpu),
        .reset(rst),
        .inst_in(instr),
        .Data_in(data_in),
        .mem_w(mem_write),
        .PC_out(pc),
        .Addr_out(data_addr),
        .Data_out(data_out),
        .dm_word_off(dm_word_off),
        .dm_funct3(dm_funct3),
        .reg_sel(sw_i[4:0]),
        .reg_data(reg_data)
    );

    dm U_DM(
        .clk(clk_cpu),
        .DMWr(ram_write),
        .addr(data_addr[8:2]),
        .word_off(dm_word_off),
        .st_funct3(dm_funct3),
        .din(data_out),
        .dout(ram_dout)
    );

    assign data_in = hit_switch ? {16'b0, sw_i} : ram_dout;

    always @(posedge clk_cpu or posedge rst) begin
        if (rst) begin
            seg7_latched <= 32'hAA55_55AA;
        end else if (mem_write && hit_seg7) begin
            seg7_latched <= data_out;
        end
    end

    always @(*) begin
        if (sw_i[5]) begin
            display_data = reg_data;
        end else begin
            case (sw_i[2:0])
                3'b000: display_data = seg7_latched;
                3'b001: display_data = {2'b0, pc[31:2]};
                3'b010: display_data = pc;
                3'b011: display_data = instr;
                3'b100: display_data = data_addr;
                3'b101: display_data = data_out;
                3'b110: display_data = ram_dout;
                3'b111: display_data = {23'b0, data_addr[8:2], 2'b00};
                default: display_data = 32'hffff_ffff;
            endcase
        end
    end

    seg7x16 U_SEG7(
        .clk(clk),
        .rstn(rstn),
        .disp_mode(1'b0),
        .i_data({32'b0, display_data}),
        .o_seg(disp_seg_o),
        .o_sel(disp_an_o)
    );

endmodule

