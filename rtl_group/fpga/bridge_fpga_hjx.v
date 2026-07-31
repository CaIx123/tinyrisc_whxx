`timescale 1ns / 1ps

`include "../top/macros.v"

module bridge_fpga_hjx(
    input wire clk,
    input wire rst_n,

    // tinyriscv soc interface
    input wire[`PWIDTH_O-1:0] tx_data_i,
    output reg [`PWIDTH_I-1:0] rx_data_o,

    // exrom interface
    input wire[31:0] data_rom_i,
    output wire[3:0] we_rom_o,
    output wire[`ROM_AWIDTH-1:0] addr_rom_o,
    output reg [31:0] data_rom_o,

    // exram interface
    input wire[31:0] data_ram_i,
    output wire[3:0] we_ram_o,
    output wire[`RAM_AWIDTH-1:0] addr_ram_o,
    output reg [31:0] data_ram_o
);

    localparam STATE_CTRL = 0;
    localparam STATE_ADDR = 1;
    localparam STATE_DATA = 2;

    reg[1:0] state;
    reg[1:0] state_next;

    reg[`EXCTRL_WIDTH-1:0] ctrl_reg;
    reg[`EX_AWIDTH-1:0] addr_reg;
    reg[31:0] data_reg;
    reg[3:0] byte_sel_mask;

    wire ctrl_vld = |tx_data_i[3:0];
    wire mem_slt = ctrl_reg[7];            // 1: rom, 0: ram
    wire transfer_write = ctrl_reg[4];     // 1: write, 0: read
    wire[3:0] byte_sel = ctrl_reg[3:0];
    wire[31:0] data_slt = mem_slt ? data_rom_i : data_ram_i;

    wire transfer_done;
    assign transfer_done = (state == STATE_DATA) &&
                   ((byte_sel & byte_sel_mask) == 4'b0001 ||
                    (byte_sel & byte_sel_mask) == 4'b0010 ||
                    (byte_sel & byte_sel_mask) == 4'b0100 ||
                    (byte_sel & byte_sel_mask) == 4'b1000);

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_CTRL;
        end else begin
            state <= state_next;
        end
    end

    always @(*) begin
        case (state)
            STATE_CTRL: begin
                state_next = ctrl_vld ? STATE_ADDR : STATE_CTRL;
            end
            STATE_ADDR: begin
                state_next = STATE_DATA;
            end
            STATE_DATA: begin
                state_next = transfer_done ? STATE_CTRL : STATE_DATA;
            end
            default: begin
                state_next = STATE_CTRL;
            end
        endcase
    end

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl_reg <= {`EXCTRL_WIDTH{1'b0}};
            addr_reg <= {`EX_AWIDTH{1'b0}};
            data_reg <= 32'h0;
        end else begin
            if (state == STATE_CTRL && ctrl_vld) begin
                ctrl_reg <= tx_data_i[`EXCTRL_WIDTH-1:0];
            end
            if (state == STATE_ADDR) begin
                addr_reg <= tx_data_i[`EX_AWIDTH-1:0];
                if (transfer_write) begin
                    data_reg <= {{(32-`EX_AWIDTH){1'b0}}, tx_data_i[`EX_AWIDTH-1:0]};
                end else begin
                    data_reg <= data_slt;
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            byte_sel_mask <= 4'b1111;
        end else begin
            if (state == STATE_DATA) begin
                casez (byte_sel & byte_sel_mask)
                    4'b???1: byte_sel_mask <= 4'b1110;
                    4'b??10: byte_sel_mask <= 4'b1100;
                    4'b?100: byte_sel_mask <= 4'b1000;
                    4'b1000: byte_sel_mask <= 4'b1111;
                    default: byte_sel_mask <= 4'b1111;
                endcase
            end else begin
                byte_sel_mask <= 4'b1111;
            end
        end
    end

    assign addr_rom_o = (state == STATE_ADDR) ? tx_data_i[`ROM_AWIDTH-1:0] :
                        addr_reg[`ROM_AWIDTH-1:0];
    assign addr_ram_o = (state == STATE_ADDR) ? tx_data_i[`RAM_AWIDTH-1:0] :
                        addr_reg[`RAM_AWIDTH-1:0];
    assign we_rom_o = (state == STATE_DATA && transfer_write && mem_slt) ? (byte_sel & byte_sel_mask) : 4'b0000;
    assign we_ram_o = (state == STATE_DATA && transfer_write && (~mem_slt)) ? (byte_sel & byte_sel_mask) : 4'b0000;

    always @(*) begin
        rx_data_o = 0;
        casez (byte_sel & byte_sel_mask)
            4'b???1: begin
                rx_data_o = data_slt[7:0];
                data_rom_o = {24'h0, tx_data_i[7:0]};
                data_ram_o = {24'h0, tx_data_i[7:0]};
            end
            4'b??10: begin
                rx_data_o = data_slt[15:8];
                data_rom_o = {16'h0, tx_data_i[7:0], 8'h0};
                data_ram_o = {16'h0, tx_data_i[7:0], 8'h0};
            end
            4'b?100: begin
                rx_data_o = data_slt[23:16];
                data_rom_o = {8'h0, tx_data_i[7:0], 16'h0};
                data_ram_o = {8'h0, tx_data_i[7:0], 16'h0};
            end
            4'b1000: begin
                rx_data_o = data_slt[31:24];
                data_rom_o = {tx_data_i[7:0], 24'h0};
                data_ram_o = {tx_data_i[7:0], 24'h0};
            end
            default: begin
                rx_data_o = {`PWIDTH_I{1'b0}};
                data_rom_o = 32'h0;
                data_ram_o = 32'h0;
            end
        endcase

        if (transfer_write | (state != STATE_DATA)) begin
            rx_data_o = {`PWIDTH_I{1'b0}};
        end
    end

endmodule
