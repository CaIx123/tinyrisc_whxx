`include "core00_wzc/marcos_wzc.v"

// FPGA verification top: ASIC PAD wrapper + FPGA ROM/RAM bridge.
module G03_fpga (
    input wire clk,
    input wire rst_n_i,
    input wire debug_en_i,
    input wire [1:0] chip_sel_i,
    output wire succ,
    output wire uart_tx_o,
    input wire uart_rx_i,
    output wire [3:0] pwm_o,
    inout wire i2c_scl,
    inout wire i2c_sda
);

    wire [`BRIDGE_WIDTH-1:0] soc_to_fpga;
    wire [`BRIDGE_WIDTH-1:0] fpga_to_soc;

    g03_top_IO u_g03_top_IO (
        .clk(clk),
        .rst_n_i(rst_n_i),
        .debug_en_i(debug_en_i),
        .chip_sel_i(chip_sel_i),
        .succ(succ),
        .bridge_tx_data_o(soc_to_fpga),
        .bridge_rx_data_i(fpga_to_soc),
        .uart_tx_o(uart_tx_o),
        .uart_rx_i(uart_rx_i),
        .pwm_o(pwm_o),
        .i2c_scl(i2c_scl),
        .i2c_sda(i2c_sda)
    );

    fpga_top u_fpga_top (
        .clk(clk),
        .rst_n(rst_n_i),
        .chip_sel_i(chip_sel_i),
        .bridge_rx_data_i(soc_to_fpga),
        .bridge_tx_data_o(fpga_to_soc),
        .i2c_scl(i2c_scl),
        .i2c_sda(i2c_sda)
    );

endmodule
