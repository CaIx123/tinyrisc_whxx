`timescale 1ns / 1ps

// Icarus-only FPGA wrapper.  It replaces the Vivado VIO IP with a direct
// chip-select input and models the two open-drain I2C buffers behaviorally.
module G03_fpga_sys_sim #(
    parameter [31:0] UART_DEBUG_BAUD_DIV = 32'd5
)(
    input  wire       clk,
    input  wire       rst_n_i,
    input  wire       debug_en_i,
    input  wire [1:0] chip_sel_i,
    output wire       succ,
    output wire       uart_tx_o,
    input  wire       uart_rx_i,
    output wire [3:0] pwm_o,
    inout  wire       i2c_scl,
    inout  wire       i2c_sda
);

    wire [7:0] bridge_soc_to_fpga;
    wire [7:0] bridge_fpga_to_soc;
    wire [1:0] i2c_io_ctrl;

    g03_soc #(
        .UART_DEBUG_BAUD_DIV(UART_DEBUG_BAUD_DIV)
    ) u_g03_soc (
        .clk              (clk),
        .rst_n_i          (rst_n_i),
        .debug_en_i       (debug_en_i),
        .chip_sel_i       (chip_sel_i),
        .succ             (succ),
        .bridge_tx_data_o (bridge_soc_to_fpga),
        .bridge_rx_data_i (bridge_fpga_to_soc),
        .uart_tx_o        (uart_tx_o),
        .uart_rx_i        (uart_rx_i),
        .pwm_o            (pwm_o),
        .i2c_io_ctrl_o    (i2c_io_ctrl),
        .i2c_scl_i        (i2c_scl),
        .i2c_sda_i        (i2c_sda)
    );

    fpga_top u_fpga_top (
        .clk              (clk),
        .rst_n            (rst_n_i),
        .chip_sel_i       (chip_sel_i),
        .bridge_rx_data_i (bridge_soc_to_fpga),
        .bridge_tx_data_o (bridge_fpga_to_soc)
    );

    // Behavioral replacements for the FPGA IOBUF primitives in G03_fpga_sys.
    // The controller uses one to release an I2C line and zero to pull it low.
    assign i2c_scl = i2c_io_ctrl[1] ? 1'bz : 1'b0;
    assign i2c_sda = i2c_io_ctrl[0] ? 1'bz : 1'b0;

endmodule
