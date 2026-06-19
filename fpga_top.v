`timescale 1ns / 1ps

module IP2SOC_Top(
    input         clk,
    input         rstn,
    input  [15:0] sw_i,
    input         ps2_clk,
    input         ps2_data,
    output [7:0]  disp_seg_o,
    output [7:0]  disp_an_o,
    output        led_shift_o
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
    wire        interrupt_active;
    wire [31:0] interrupt_epc;

    localparam IO_SWITCH     = 32'hffff_0004;
    localparam IO_SEG7       = 32'hffff_000c;
    localparam IO_KBD_DATA   = 32'hffff_0010;
    localparam IO_KBD_STATUS = 32'hffff_0014;
    localparam IO_IRQ_RET    = 32'hffff_0018;

    wire hit_switch     = (data_addr == IO_SWITCH);
    wire hit_seg7       = (data_addr == IO_SEG7);
    wire hit_kbd_data   = (data_addr == IO_KBD_DATA);
    wire hit_kbd_status = (data_addr == IO_KBD_STATUS);
    wire hit_irq_ret    = (data_addr == IO_IRQ_RET);
    wire hit_io         = hit_switch || hit_seg7 || hit_kbd_data || hit_kbd_status || hit_irq_ret;
    wire ram_write      = mem_write && !hit_io;
    wire intr_ret       = mem_write && hit_irq_ret && data_out[0];

    wire [7:0] ps2_scan_code;
    wire       ps2_scan_ready;
    wire [7:0] ascii_code;
    wire       ascii_ready;
    wire       kbd_shift_down;
    wire [7:0] kbd_key_cpu;
    wire [7:0] kbd_scan_cpu;
    wire       kbd_valid_cpu;
    wire [7:0] kbd_data;
    wire [7:0] kbd_last_scan;
    wire       kbd_ready;
    wire       kbd_irq;
    wire       kbd_clear = mem_write && hit_kbd_status && data_out[0];

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
        .reg_data(reg_data),
        .irq(kbd_irq),
        .intr_ret(intr_ret),
        .interrupt_active(interrupt_active),
        .interrupt_epc(interrupt_epc)
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

    ps2_keyboard_receiver U_PS2_RX(
        .clk(clk),
        .rst(rst),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .scan_code(ps2_scan_code),
        .scan_ready(ps2_scan_ready)
    );

    keyboard_ascii_decoder U_KBD_DEC(
        .clk(clk),
        .rst(rst),
        .scan_code(ps2_scan_code),
        .scan_ready(ps2_scan_ready),
        .ascii_code(ascii_code),
        .ascii_ready(ascii_ready),
        .shift_down(kbd_shift_down)
    );

    assign led_shift_o = kbd_shift_down;

    keyboard_event_sync U_KBD_SYNC(
        .src_clk(clk),
        .src_rst(rst),
        .src_key(ascii_code),
        .src_scan(ps2_scan_code),
        .src_valid(ascii_ready),
        .dst_clk(clk_cpu),
        .dst_rst(rst),
        .dst_key(kbd_key_cpu),
        .dst_scan(kbd_scan_cpu),
        .dst_valid(kbd_valid_cpu)
    );

    keyboard_io U_KBD_IO(
        .clk(clk_cpu),
        .rst(rst),
        .key_code(kbd_key_cpu),
        .scan_code(kbd_scan_cpu),
        .key_valid(kbd_valid_cpu),
        .clear(kbd_clear),
        .data(kbd_data),
        .last_scan(kbd_last_scan),
        .ready(kbd_ready),
        .irq(kbd_irq)
    );

    assign data_in = hit_switch     ? {16'b0, sw_i} :
                     hit_kbd_data   ? {24'b0, kbd_data} :
                     hit_kbd_status ? {16'b0, kbd_last_scan, 6'b0, interrupt_active, kbd_ready} :
                     hit_irq_ret    ? interrupt_epc :
                                      ram_dout;

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
                3'b110: display_data = data_in;
                3'b111: display_data = {16'b0, kbd_data, kbd_last_scan};
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

module ps2_keyboard_receiver(
    input        clk,
    input        rst,
    input        ps2_clk,
    input        ps2_data,
    output reg [7:0] scan_code,
    output reg       scan_ready
);
    reg [2:0] ps2_clk_sync;
    reg [10:0] frame;
    reg [3:0] bit_count;

    wire ps2_clk_fall = (ps2_clk_sync[2:1] == 2'b10);
    wire odd_parity_ok = ((^frame[8:1]) ^ frame[9]);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ps2_clk_sync <= 3'b111;
        end else begin
            ps2_clk_sync <= {ps2_clk_sync[1:0], ps2_clk};
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            frame <= 11'b0;
            bit_count <= 4'd0;
            scan_code <= 8'b0;
            scan_ready <= 1'b0;
        end else begin
            scan_ready <= 1'b0;
            if (ps2_clk_fall) begin
                frame[bit_count] <= ps2_data;
                if (bit_count == 4'd10) begin
                    bit_count <= 4'd0;
                    if ((frame[0] == 1'b0) && (ps2_data == 1'b1) && odd_parity_ok) begin
                        scan_code <= frame[8:1];
                        scan_ready <= 1'b1;
                    end
                end else begin
                    bit_count <= bit_count + 1'b1;
                end
            end
        end
    end
endmodule

module keyboard_ascii_decoder(
    input        clk,
    input        rst,
    input  [7:0] scan_code,
    input        scan_ready,
    output reg [7:0] ascii_code,
    output reg       ascii_ready,
    output           shift_down
);
    reg break_pending;
    reg extend_pending;

    reg shift_l_down;
    reg shift_r_down;
    reg caps_lock;
    reg caps_lock_down;

    assign shift_down = shift_l_down || shift_r_down;

    function [7:0] scan_to_ascii;
        input [7:0] code;
        input shift;
        input caps;
        reg upper;
        begin
            upper = shift ^ caps;
            case (code)
                8'h1C: scan_to_ascii = upper ? 8'h41 : 8'h61; // A/a
                8'h32: scan_to_ascii = upper ? 8'h42 : 8'h62; // B/b
                8'h21: scan_to_ascii = upper ? 8'h43 : 8'h63; // C/c
                8'h23: scan_to_ascii = upper ? 8'h44 : 8'h64; // D/d
                8'h24: scan_to_ascii = upper ? 8'h45 : 8'h65; // E/e
                8'h2B: scan_to_ascii = upper ? 8'h46 : 8'h66; // F/f
                8'h34: scan_to_ascii = upper ? 8'h47 : 8'h67; // G/g
                8'h33: scan_to_ascii = upper ? 8'h48 : 8'h68; // H/h
                8'h43: scan_to_ascii = upper ? 8'h49 : 8'h69; // I/i
                8'h3B: scan_to_ascii = upper ? 8'h4A : 8'h6A; // J/j
                8'h42: scan_to_ascii = upper ? 8'h4B : 8'h6B; // K/k
                8'h4B: scan_to_ascii = upper ? 8'h4C : 8'h6C; // L/l
                8'h3A: scan_to_ascii = upper ? 8'h4D : 8'h6D; // M/m
                8'h31: scan_to_ascii = upper ? 8'h4E : 8'h6E; // N/n
                8'h44: scan_to_ascii = upper ? 8'h4F : 8'h6F; // O/o
                8'h4D: scan_to_ascii = upper ? 8'h50 : 8'h70; // P/p
                8'h15: scan_to_ascii = upper ? 8'h51 : 8'h71; // Q/q
                8'h2D: scan_to_ascii = upper ? 8'h52 : 8'h72; // R/r
                8'h1B: scan_to_ascii = upper ? 8'h53 : 8'h73; // S/s
                8'h2C: scan_to_ascii = upper ? 8'h54 : 8'h74; // T/t
                8'h3C: scan_to_ascii = upper ? 8'h55 : 8'h75; // U/u
                8'h2A: scan_to_ascii = upper ? 8'h56 : 8'h76; // V/v
                8'h1D: scan_to_ascii = upper ? 8'h57 : 8'h77; // W/w
                8'h22: scan_to_ascii = upper ? 8'h58 : 8'h78; // X/x
                8'h35: scan_to_ascii = upper ? 8'h59 : 8'h79; // Y/y
                8'h1A: scan_to_ascii = upper ? 8'h5A : 8'h7A; // Z/z
                8'h45: scan_to_ascii = shift ? 8'h29 : 8'h30; // 0/)
                8'h16: scan_to_ascii = shift ? 8'h21 : 8'h31; // 1/!
                8'h1E: scan_to_ascii = shift ? 8'h40 : 8'h32; // 2/@
                8'h26: scan_to_ascii = shift ? 8'h23 : 8'h33; // 3/#
                8'h25: scan_to_ascii = shift ? 8'h24 : 8'h34; // 4/$
                8'h2E: scan_to_ascii = shift ? 8'h25 : 8'h35; // 5/%
                8'h36: scan_to_ascii = shift ? 8'h5E : 8'h36; // 6/^
                8'h3D: scan_to_ascii = shift ? 8'h26 : 8'h37; // 7/&
                8'h3E: scan_to_ascii = shift ? 8'h2A : 8'h38; // 8/*
                8'h46: scan_to_ascii = shift ? 8'h28 : 8'h39; // 9/(
                8'h0E: scan_to_ascii = shift ? 8'h7E : 8'h60; // `/~
                8'h4E: scan_to_ascii = shift ? 8'h5F : 8'h2D; // -/_
                8'h55: scan_to_ascii = shift ? 8'h2B : 8'h3D; // =/+
                8'h54: scan_to_ascii = shift ? 8'h7B : 8'h5B; // [/{
                8'h5B: scan_to_ascii = shift ? 8'h7D : 8'h5D; // ]/}
                8'h5D: scan_to_ascii = shift ? 8'h7C : 8'h5C; // \/|
                8'h4C: scan_to_ascii = shift ? 8'h3A : 8'h3B; // ;/:
                8'h52: scan_to_ascii = shift ? 8'h22 : 8'h27; // '/"
                8'h41: scan_to_ascii = shift ? 8'h3C : 8'h2C; // ,/<
                8'h49: scan_to_ascii = shift ? 8'h3E : 8'h2E; // ./>
                8'h4A: scan_to_ascii = shift ? 8'h3F : 8'h2F; // //?
                8'h29: scan_to_ascii = 8'h20; // Space
                8'h5A: scan_to_ascii = 8'h0D; // Enter
                8'h66: scan_to_ascii = 8'h08; // Backspace
                8'h0D: scan_to_ascii = 8'h09; // Tab
                8'h76: scan_to_ascii = 8'h1B; // Esc
                default: scan_to_ascii = 8'h00;
            endcase
        end
    endfunction

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            break_pending <= 1'b0;
            extend_pending <= 1'b0;
            shift_l_down <= 1'b0;
            shift_r_down <= 1'b0;
            caps_lock <= 1'b0;
            caps_lock_down <= 1'b0;
            ascii_code <= 8'b0;
            ascii_ready <= 1'b0;
        end else begin
            ascii_ready <= 1'b0;
            if (scan_ready) begin
                if (scan_code == 8'hE0) begin
                    extend_pending <= 1'b1;
                end else if (scan_code == 8'hF0) begin
                    break_pending <= 1'b1;
                end else if (break_pending) begin
                    if (scan_code == 8'h12) begin
                        shift_l_down <= 1'b0;
                    end else if (scan_code == 8'h59) begin
                        shift_r_down <= 1'b0;
                    end else if (scan_code == 8'h58) begin
                        caps_lock_down <= 1'b0;
                    end
                    break_pending <= 1'b0;
                    extend_pending <= 1'b0;
                end else if (scan_code == 8'h12) begin
                    shift_l_down <= 1'b1;
                    extend_pending <= 1'b0;
                end else if (scan_code == 8'h59) begin
                    shift_r_down <= 1'b1;
                    extend_pending <= 1'b0;
                end else if (scan_code == 8'h58) begin
                    if (!caps_lock_down) begin
                        caps_lock <= ~caps_lock;
                    end
                    caps_lock_down <= 1'b1;
                    extend_pending <= 1'b0;
                end else begin
                    ascii_code <= scan_to_ascii(scan_code, shift_l_down || shift_r_down, caps_lock);
                    ascii_ready <= (scan_to_ascii(scan_code, shift_l_down || shift_r_down, caps_lock) != 8'h00) && !extend_pending;
                    extend_pending <= 1'b0;
                end
            end
        end
    end
endmodule

module keyboard_event_sync(
    input        src_clk,
    input        src_rst,
    input  [7:0] src_key,
    input  [7:0] src_scan,
    input        src_valid,
    input        dst_clk,
    input        dst_rst,
    output reg [7:0] dst_key,
    output reg [7:0] dst_scan,
    output reg       dst_valid
);
    reg [7:0] src_key_hold;
    reg [7:0] src_scan_hold;
    reg       src_toggle;
    reg [2:0] dst_toggle_sync;

    always @(posedge src_clk or posedge src_rst) begin
        if (src_rst) begin
            src_key_hold <= 8'b0;
            src_scan_hold <= 8'b0;
            src_toggle <= 1'b0;
        end else if (src_valid) begin
            src_key_hold <= src_key;
            src_scan_hold <= src_scan;
            src_toggle <= ~src_toggle;
        end
    end

    always @(posedge dst_clk or posedge dst_rst) begin
        if (dst_rst) begin
            dst_toggle_sync <= 3'b0;
            dst_key <= 8'b0;
            dst_scan <= 8'b0;
            dst_valid <= 1'b0;
        end else begin
            dst_toggle_sync <= {dst_toggle_sync[1:0], src_toggle};
            dst_valid <= dst_toggle_sync[2] ^ dst_toggle_sync[1];
            if (dst_toggle_sync[2] ^ dst_toggle_sync[1]) begin
                dst_key <= src_key_hold;
                dst_scan <= src_scan_hold;
            end
        end
    end
endmodule

module keyboard_io(
    input        clk,
    input        rst,
    input  [7:0] key_code,
    input  [7:0] scan_code,
    input        key_valid,
    input        clear,
    output reg [7:0] data,
    output reg [7:0] last_scan,
    output reg       ready,
    output           irq
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            data <= 8'b0;
            last_scan <= 8'b0;
            ready <= 1'b0;
        end else begin
            if (clear) begin
                ready <= 1'b0;
            end
            if (key_valid) begin
                data <= key_code;
                last_scan <= scan_code;
                ready <= 1'b1;
            end
        end
    end

    assign irq = ready;
endmodule
