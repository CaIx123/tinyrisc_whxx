`include "../tiny_macro.v"

module FPGA_top(
    input wire clk,
    input wire rst_n,

    input wire[`PWIDTH_O-1:0] tx_data_i,
    output wire[`PWIDTH_I-1:0] rx_data_o
);

    wire[31:0] exrom_data_i;
    wire[31:0] exrom_data_o;
    wire[3:0] exrom_we;
    wire[`ROM_AWIDTH-1:0] exrom_addr;

    wire[31:0] exram_data_i;
    wire[31:0] exram_data_o;
    wire[3:0] exram_we;
    wire[`RAM_AWIDTH-1:0] exram_addr;

    bridge_FPGA u_ex_bridge(
        .clk(clk),
        .rst_n(rst_n),
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
        .rst_n(rst_n),
        .we_i(exrom_we),
        .addr_i(exrom_addr),
        .data_i(exrom_data_o),
        .data_o(exrom_data_i)
    );

    exram u_exram(
        .clk(clk),
        .rst_n(rst_n),
        .we_i(exram_we),
        .addr_i(exram_addr),
        .data_i(exram_data_o),
        .data_o(exram_data_i)
    );

endmodule
