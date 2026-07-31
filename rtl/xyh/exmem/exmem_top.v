`include "../tiny_macro.v"

// 外部存储子系统顶层
// 将ex_bridge、exrom、exram封装成一个子系统模块
// 通过8bit串行接口与片上通信
module exmem_top(
    input wire clk,                          // 时钟
    input wire rst,                          // 复位(高有效)

    input wire[`PWIDTH_O-1:0] tx_data_i,     // 来自片上侧的串行数据
    output wire[`PWIDTH_I-1:0] rx_data_o     // 发往片上侧的串行数据
);

    wire[31:0] exrom_data_i;
    wire[31:0] exrom_data_o;
    wire[3:0] exrom_we;
    wire[`ROM_AWIDTH-1:0] exrom_addr;

    wire[31:0] exram_data_i;
    wire[31:0] exram_data_o;
    wire[3:0] exram_we;
    wire[`RAM_AWIDTH-1:0] exram_addr;

    ex_bridge u_ex_bridge(
        .clk(clk),
        .rst(rst),
        .tx_data_i(tx_data_i),
        .rx_data_o(rx_data_o),

        .data_rom_i(exrom_data_i),
        .we_rom_o(exrom_we),
        .addr_rom_o(exrom_addr),
        .data_rom_o(exrom_data_o),

        .data_ram_i(exram_data_i),
        .we_ram_o(exram_we),
        .addr_ram_o(exram_addr),
        .data_ram_o(exram_data_o)
    );

    exrom u_exrom(
        .clk(clk),
        .rst(rst),
        .we_i(exrom_we),
        .addr_i(exrom_addr),
        .data_i(exrom_data_o),
        .data_o(exrom_data_i)
    );

    exram u_exram(
        .clk(clk),
        .rst(rst),
        .we_i(exram_we),
        .addr_i(exram_addr),
        .data_i(exram_data_o),
        .data_o(exram_data_i)
    );

endmodule
