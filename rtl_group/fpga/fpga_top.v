`timescale 1ns / 1ps

`include "../top/macros.v"

module fpga_top(
    input wire clk,
    input wire rst_n,
    input wire [1:0] chip_sel_i,
    input wire [`BRIDGE_WIDTH-1:0] bridge_rx_data_i,
    output wire [`BRIDGE_WIDTH-1:0] bridge_tx_data_o,
    inout wire i2c_scl,
    inout wire i2c_sda
);
    wire [`INST_WIDTH-1:0] rom_data_i;
    wire [`DATA_WIDTH-1:0] ram_data_i;

    wire [7:0] tx_wzc;
    wire wzc_rom_we, wzc_ram_we;
    wire [3:0] wzc_rom_sel, wzc_ram_sel;
    wire [`ROM_ADDR_WIDTH-1:0] wzc_rom_addr;
    wire [`RAM_ADDR_WIDTH-1:0] wzc_ram_addr;
    wire [31:0] wzc_rom_wdata, wzc_ram_wdata;

    wire [7:0] tx_xyh;
    wire [3:0] xyh_rom_we, xyh_ram_we;
    wire [`ROM_ADDR_WIDTH-1:0] xyh_rom_addr;
    wire [`RAM_ADDR_WIDTH-1:0] xyh_ram_addr;
    wire [31:0] xyh_rom_wdata, xyh_ram_wdata;

    wire [7:0] tx_hjx;
    wire [3:0] hjx_rom_we, hjx_ram_we;
    wire [`ROM_ADDR_WIDTH-1:0] hjx_rom_addr;
    wire [`RAM_ADDR_WIDTH-1:0] hjx_ram_addr;
    wire [31:0] hjx_rom_wdata, hjx_ram_wdata;

    wire [7:0] tx_xzr;
    wire xzr_rom_we, xzr_ram_we;
    wire [31:0] xzr_mem_addr, xzr_mem_wdata;

    wire select_wzc = chip_sel_i == 2'b00;
    wire select_xyh = chip_sel_i == 2'b01;
    wire select_hjx = chip_sel_i == 2'b10;
    wire select_xzr = chip_sel_i == 2'b11;

    bridge_fpga_wzc u_bridge_fpga_wzc(
        .clk(clk), .rst_n(rst_n & select_wzc),
        .rx_data_i(select_wzc ? bridge_rx_data_i : 8'b0),
        .tx_data_o(tx_wzc),
        .data_rom_i(rom_data_i), .we_rom_o(wzc_rom_we),
        .sel_rom_o(wzc_rom_sel), .addr_rom_o(wzc_rom_addr),
        .data_rom_o(wzc_rom_wdata),
        .data_ram_i(ram_data_i), .we_ram_o(wzc_ram_we),
        .sel_ram_o(wzc_ram_sel), .addr_ram_o(wzc_ram_addr),
        .data_ram_o(wzc_ram_wdata)
    );

    bridge_fpga_xyh u_bridge_fpga_xyh(
        .clk(clk), .rst(~rst_n | ~select_xyh),
        .tx_data_i(select_xyh ? bridge_rx_data_i : 8'b0),
        .rx_data_o(tx_xyh),
        .data_rom_i(rom_data_i), .we_rom_o(xyh_rom_we),
        .addr_rom_o(xyh_rom_addr), .data_rom_o(xyh_rom_wdata),
        .data_ram_i(ram_data_i), .we_ram_o(xyh_ram_we),
        .addr_ram_o(xyh_ram_addr), .data_ram_o(xyh_ram_wdata)
    );

    bridge_fpga_hjx u_bridge_fpga_hjx(
        .clk(clk), .rst_n(rst_n & select_hjx),
        .tx_data_i(select_hjx ? bridge_rx_data_i : 8'b0),
        .rx_data_o(tx_hjx),
        .data_rom_i(rom_data_i), .we_rom_o(hjx_rom_we),
        .addr_rom_o(hjx_rom_addr), .data_rom_o(hjx_rom_wdata),
        .data_ram_i(ram_data_i), .we_ram_o(hjx_ram_we),
        .addr_ram_o(hjx_ram_addr), .data_ram_o(hjx_ram_wdata)
    );

    bridge_fpga_xzr u_bridge_fpga_xzr(
        .clk(clk), .rst(rst_n & select_xzr),
        .rx_8bit(select_xzr ? bridge_rx_data_i : 8'b0),
        .tx_8bit(tx_xzr),
        .mem_addr(xzr_mem_addr), .mem_wdata(xzr_mem_wdata),
        .rom_we(xzr_rom_we), .ram_we(xzr_ram_we),
        .rom_data(rom_data_i), .ram_data(ram_data_i)
    );

    assign bridge_tx_data_o = select_wzc ? tx_wzc :
                              select_xyh ? tx_xyh :
                              select_hjx ? tx_hjx :
                              select_xzr ? tx_xzr : 8'b0;

    wire rom_we = select_wzc ? wzc_rom_we :
                  select_xyh ? |xyh_rom_we :
                  select_hjx ? |hjx_rom_we :
                  select_xzr ? xzr_rom_we : 1'b0;
    wire [3:0] rom_sel = select_wzc ? wzc_rom_sel :
                         select_xyh ? xyh_rom_we :
                         select_hjx ? hjx_rom_we :
                         select_xzr ? 4'b1111 : 4'b0;
    wire [`ROM_ADDR_WIDTH-1:0] rom_addr =
                         select_wzc ? wzc_rom_addr :
                         select_xyh ? xyh_rom_addr :
                         select_hjx ? hjx_rom_addr :
                         select_xzr ? xzr_mem_addr[`ROM_ADDR_WIDTH+1:2] :
                                      {`ROM_ADDR_WIDTH{1'b0}};
    wire [31:0] rom_data_o = select_wzc ? wzc_rom_wdata :
                             select_xyh ? xyh_rom_wdata :
                             select_hjx ? hjx_rom_wdata :
                             select_xzr ? xzr_mem_wdata : 32'b0;

    wire ram_we = select_wzc ? wzc_ram_we :
                  select_xyh ? |xyh_ram_we :
                  select_hjx ? |hjx_ram_we :
                  select_xzr ? xzr_ram_we : 1'b0;
    wire [3:0] ram_sel = select_wzc ? wzc_ram_sel :
                         select_xyh ? xyh_ram_we :
                         select_hjx ? hjx_ram_we :
                         select_xzr ? 4'b1111 : 4'b0;
    wire [`RAM_ADDR_WIDTH-1:0] ram_addr =
                         select_wzc ? wzc_ram_addr :
                         select_xyh ? xyh_ram_addr :
                         select_hjx ? hjx_ram_addr :
                         select_xzr ? xzr_mem_addr[`RAM_ADDR_WIDTH+1:2] :
                                      {`RAM_ADDR_WIDTH{1'b0}};
    wire [31:0] ram_data_o = select_wzc ? wzc_ram_wdata :
                             select_xyh ? xyh_ram_wdata :
                             select_hjx ? hjx_ram_wdata :
                             select_xzr ? xzr_mem_wdata : 32'b0;

    rom #(
        .ROM_DEPTH(`ROM_DEPTH), .INST_WIDTH(`INST_WIDTH),
        .ROM_ADDR_WIDTH(`ROM_ADDR_WIDTH)
    ) u_rom(
        .clk(clk), .rst_n(rst_n), .addr_i(rom_addr),
        .data_i(rom_data_o), .sel_i(rom_sel), .we_i(rom_we),
        .data_o(rom_data_i)
    );

    ram #(
        .RAM_DEPTH(`RAM_DEPTH), .DATA_WIDTH(`DATA_WIDTH),
        .RAM_ADDR_WIDTH(`RAM_ADDR_WIDTH)
    ) u_ram(
        .clk(clk), .rst_n(rst_n), .addr_i(ram_addr),
        .data_i(ram_data_o), .sel_i(ram_sel), .we_i(ram_we),
        .data_o(ram_data_i)
    );

endmodule
