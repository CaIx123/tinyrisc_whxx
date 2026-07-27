`include "../core00_wzc/marcos_wzc.v"

module fpga_top(

    input wire clk,
    input wire rst_n,
    input wire [1:0] chip_sel_i,

    input wire[`BRIDGE_WIDTH-1:0] bridge_rx_data_i,
    output wire[`BRIDGE_WIDTH-1:0] bridge_tx_data_o,

    inout wire i2c_scl,
    inout wire i2c_sda

    );

    // WZC, XYH and XZR use the existing shared FPGA image and bridge.
    // HJX keeps its original FPGA-side timing in a separate image and bridge.
    wire bridge_hjx_selected = chip_sel_i == 2'b10;
    wire bridge_shared_selected = ~bridge_hjx_selected;
    wire [`BRIDGE_WIDTH-1:0] bridge_shared_rx_data =
        bridge_shared_selected ? bridge_rx_data_i : {`BRIDGE_WIDTH{1'b0}};
    wire [`BRIDGE_WIDTH-1:0] bridge_hjx_rx_data =
        bridge_hjx_selected ? bridge_rx_data_i : {`BRIDGE_WIDTH{1'b0}};
    wire [`BRIDGE_WIDTH-1:0] bridge_shared_tx_data;
    wire [`BRIDGE_WIDTH-1:0] bridge_hjx_tx_data;

    wire [`INST_WIDTH-1:0] shared_rom_data_i;
    wire shared_rom_we;
    wire [3:0] shared_rom_sel;
    wire [`ROM_ADDR_WIDTH-1:0] shared_rom_addr;
    wire [`INST_WIDTH-1:0] shared_rom_data_o;
    wire [`DATA_WIDTH-1:0] shared_ram_data_i;
    wire shared_ram_we;
    wire [3:0] shared_ram_sel;
    wire [`RAM_ADDR_WIDTH-1:0] shared_ram_addr;
    wire [`DATA_WIDTH-1:0] shared_ram_data_o;

    wire [31:0] hjx_rom_data_i;
    wire [3:0] hjx_rom_we;
    wire [`ROM_ADDR_WIDTH-1:0] hjx_rom_addr;
    wire [31:0] hjx_rom_data_o;
    wire [31:0] hjx_ram_data_i;
    wire [3:0] hjx_ram_we;
    wire [`RAM_ADDR_WIDTH-1:0] hjx_ram_addr;
    wire [31:0] hjx_ram_data_o;

    bridge_fpga u_bridge_fpga(
        .clk(clk),
        .rst_n(rst_n),
        .rx_data_i(bridge_shared_rx_data),
        .tx_data_o(bridge_shared_tx_data),
        .data_rom_i(shared_rom_data_i),
        .we_rom_o(shared_rom_we),
        .sel_rom_o(shared_rom_sel),
        .addr_rom_o(shared_rom_addr),
        .data_rom_o(shared_rom_data_o),
        .data_ram_i(shared_ram_data_i),
        .we_ram_o(shared_ram_we),
        .sel_ram_o(shared_ram_sel),
        .addr_ram_o(shared_ram_addr),
        .data_ram_o(shared_ram_data_o)
    );

    rom #(
        .ROM_DEPTH(`ROM_DEPTH),
        .INST_WIDTH(`INST_WIDTH),
        .ROM_ADDR_WIDTH(`ROM_ADDR_WIDTH)
    ) u_rom(
        .clk(clk),
        .rst_n(rst_n),
        .addr_i(shared_rom_addr),
        .data_i(shared_rom_data_o),
        .sel_i(shared_rom_sel),
        .we_i(shared_rom_we),
        .data_o(shared_rom_data_i)
    );

    ram #(
        .RAM_DEPTH(`RAM_DEPTH),
        .DATA_WIDTH(`DATA_WIDTH),
        .RAM_ADDR_WIDTH(`RAM_ADDR_WIDTH)
    ) u_ram(
        .clk(clk),
        .rst_n(rst_n),
        .addr_i(shared_ram_addr),
        .data_i(shared_ram_data_o),
        .sel_i(shared_ram_sel),
        .we_i(shared_ram_we),
        .data_o(shared_ram_data_i)
    );

    bridge_fpga_hjx u_bridge_fpga_hjx(
        .clk(clk),
        .rst_n(rst_n),
        .rx_data_i(bridge_hjx_rx_data),
        .tx_data_o(bridge_hjx_tx_data),
        .data_rom_i(hjx_rom_data_i),
        .we_rom_o(hjx_rom_we),
        .addr_rom_o(hjx_rom_addr),
        .data_rom_o(hjx_rom_data_o),
        .data_ram_i(hjx_ram_data_i),
        .we_ram_o(hjx_ram_we),
        .addr_ram_o(hjx_ram_addr),
        .data_ram_o(hjx_ram_data_o)
    );

    rom_hjx u_rom_hjx(
        .clk(clk),
        .rst_n(rst_n),
        .we_i(hjx_rom_we),
        .addr_i(hjx_rom_addr),
        .data_i(hjx_rom_data_o),
        .data_o(hjx_rom_data_i)
    );

    ram_hjx u_ram_hjx(
        .clk(clk),
        .rst_n(rst_n),
        .we_i(hjx_ram_we),
        .addr_i(hjx_ram_addr),
        .data_i(hjx_ram_data_o),
        .data_o(hjx_ram_data_i)
    );

    assign bridge_tx_data_o = bridge_hjx_selected ? bridge_hjx_tx_data :
                                                     bridge_shared_tx_data;

    // lm75_model u_lm75_model(
    //     .clk(clk),
    //     .rst_n(rst_n),
    //     .scl(i2c_scl),
    //     .sda(i2c_sda)
    // );

endmodule
