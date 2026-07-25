`include "../core00_wzc/marcos.v"

module fpga_top(

    input wire clk,
    input wire rst_n,

    input wire[`BRIDGE_WIDTH-1:0] bridge_rx_data_i,
    output wire[`BRIDGE_WIDTH-1:0] bridge_tx_data_o,

    inout wire i2c_scl,
    inout wire i2c_sda

    );

    wire[`INST_WIDTH-1:0] rom_data_i;
    wire rom_we;
    wire[3:0] rom_sel;
    wire[`ROM_ADDR_WIDTH-1:0] rom_addr;
    wire[`INST_WIDTH-1:0] rom_data_o;

    wire[`DATA_WIDTH-1:0] ram_data_i;
    wire ram_we;
    wire[3:0] ram_sel;
    wire[`RAM_ADDR_WIDTH-1:0] ram_addr;
    wire[`DATA_WIDTH-1:0] ram_data_o;

    bridge_fpga u_bridge_fpga(
        .clk(clk),
        .rst_n(rst_n),
        .rx_data_i(bridge_rx_data_i),
        .tx_data_o(bridge_tx_data_o),
        .data_rom_i(rom_data_i),
        .we_rom_o(rom_we),
        .sel_rom_o(rom_sel),
        .addr_rom_o(rom_addr),
        .data_rom_o(rom_data_o),
        .data_ram_i(ram_data_i),
        .we_ram_o(ram_we),
        .sel_ram_o(ram_sel),
        .addr_ram_o(ram_addr),
        .data_ram_o(ram_data_o)
    );

    rom #(
        .ROM_DEPTH(`ROM_DEPTH),
        .INST_WIDTH(`INST_WIDTH),
        .ROM_ADDR_WIDTH(`ROM_ADDR_WIDTH)
    ) u_rom(
        .clk(clk),
        .rst_n(rst_n),
        .addr_i(rom_addr),
        .data_i(rom_data_o),
        .sel_i(rom_sel),
        .we_i(rom_we),
        .data_o(rom_data_i)
    );

    ram #(
        .RAM_DEPTH(`RAM_DEPTH),
        .DATA_WIDTH(`DATA_WIDTH),
        .RAM_ADDR_WIDTH(`RAM_ADDR_WIDTH)
    ) u_ram(
        .clk(clk),
        .rst_n(rst_n),
        .addr_i(ram_addr),
        .data_i(ram_data_o),
        .sel_i(ram_sel),
        .we_i(ram_we),
        .data_o(ram_data_i)
    );

    // lm75_model u_lm75_model(
    //     .clk(clk),
    //     .rst_n(rst_n),
    //     .scl(i2c_scl),
    //     .sda(i2c_sda)
    // );

endmodule
