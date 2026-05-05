`timescale 1ns / 1ps

module CLK_DIV(
    input  clk,
    input  rst,
    input  SW15,
    output Clk_CPU
);

    reg [31:0] clkdiv;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            clkdiv <= 32'b0;
        end else begin
            clkdiv <= clkdiv + 1'b1;
        end
    end

    assign Clk_CPU = SW15 ? clkdiv[25] : clkdiv[2];

endmodule

