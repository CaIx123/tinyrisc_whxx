// 片外协议解释器(与rib_bridge成对工作)
// 从8bit串行数据中恢复目标存储体、读写方向、字节掩码、地址和数据
// 然后访问exrom或exram，将返回数据拆成8bit返回给片上侧
module bridge_fpga_xyh(
    input wire clk,                          // 时钟
    input wire rst,                          // 复位(高有效)

    // tinyriscv soc interface
    input wire[7:0] tx_data_i,               // 来自片上侧的串行数据
    output reg [7:0] rx_data_o,              // 发往片上侧的串行数据

    // exrom interface
    input wire[31:0] data_rom_i,             // ROM读数据
    output wire[3:0] we_rom_o,               // ROM字节写使能
    output wire[7:0] addr_rom_o,             // ROM地址
    output reg [31:0] data_rom_o,            // ROM写数据

    // exram interface
    input wire[31:0] data_ram_i,             // RAM读数据
    output wire[3:0] we_ram_o,               // RAM字节写使能
    output wire[3:0] addr_ram_o,             // RAM地址
    output reg [31:0] data_ram_o             // RAM写数据
);

    localparam TR_CTRL = 0;
    localparam TR_ADDR = 1;
    localparam TR_DATA = 2;

    reg [1:0] tr_state, next_tr_state;

    reg[7:0] ctrl_reg;
    reg[7:0] addr_reg;
    reg[31:0] data_reg;
    reg[3:0] byte_sel_bitmask;

    wire ctrl_vld = |tx_data_i[3:0];
    wire mem_slt = ctrl_reg[7];            // 1: rom, 0: ram
    wire tr_dir = ctrl_reg[4];             // 1: write, 0: read
    wire[3:0] byte_sel = ctrl_reg[3:0];
    wire[31:0] data_slt = mem_slt ? data_rom_i : data_ram_i;

    wire tr_fn;
    assign tr_fn = (tr_state == TR_DATA) &&
                   ((byte_sel & byte_sel_bitmask) == 4'b0001 ||
                    (byte_sel & byte_sel_bitmask) == 4'b0010 ||
                    (byte_sel & byte_sel_bitmask) == 4'b0100 ||
                    (byte_sel & byte_sel_bitmask) == 4'b1000);

    always @ (posedge clk or posedge rst) begin
        if (rst) begin
            tr_state <= TR_CTRL;
        end else begin
            tr_state <= next_tr_state;
        end
    end

    always @(*) begin
        case (tr_state)
            TR_CTRL: next_tr_state = ctrl_vld ? TR_ADDR : TR_CTRL;
            TR_ADDR: next_tr_state = TR_DATA;
            TR_DATA: next_tr_state = tr_fn ? TR_CTRL : TR_DATA;
            default: next_tr_state = TR_CTRL;
        endcase
    end

    always @ (posedge clk or posedge rst) begin
        if (rst) begin
            ctrl_reg <= 8'b0;
            addr_reg <= 8'b0;
            data_reg <= 32'h0;
        end else begin
            if (tr_state == TR_CTRL && ctrl_vld) begin
                ctrl_reg <= tx_data_i[7:0];
            end
            if (tr_state == TR_ADDR) begin
                addr_reg <= tx_data_i[7:0];
                if (tr_dir) begin
                    data_reg <= {24'b0, tx_data_i[7:0]};
                end else begin
                    data_reg <= data_slt;
                end
            end
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            byte_sel_bitmask <= 4'b1111;
        end else begin
            if (tr_state == TR_DATA) begin
                casez (byte_sel & byte_sel_bitmask)
                    4'b???1: byte_sel_bitmask <= 4'b1110;
                    4'b??10: byte_sel_bitmask <= 4'b1100;
                    4'b?100: byte_sel_bitmask <= 4'b1000;
                    4'b1000: byte_sel_bitmask <= 4'b1111;
                    default: byte_sel_bitmask <= 4'b1111;
                endcase
            end else begin
                byte_sel_bitmask <= 4'b1111;
            end
        end
    end

    assign addr_rom_o = (tr_state == TR_ADDR) ? tx_data_i[7:0] : addr_reg;
    assign addr_ram_o = (tr_state == TR_ADDR) ? tx_data_i[3:0] : addr_reg[3:0];
    assign we_rom_o = (tr_state == TR_DATA && tr_dir && mem_slt) ? (byte_sel & byte_sel_bitmask) : 4'b0000;
    assign we_ram_o = (tr_state == TR_DATA && tr_dir && (~mem_slt)) ? (byte_sel & byte_sel_bitmask) : 4'b0000;

    always @(*) begin
        rx_data_o = 0;
        casez (byte_sel & byte_sel_bitmask)
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
                rx_data_o = 8'b0;
                data_rom_o = 32'h0;
                data_ram_o = 32'h0;
            end
        endcase

        if (tr_dir | (tr_state != TR_DATA)) begin
            rx_data_o = 8'b0;
        end
    end

endmodule
