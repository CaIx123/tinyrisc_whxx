`include "core/defines.v"
`include "tiny_macro.v"

module tinyriscv_sys_top(
    input  wire       clk,
    input  wire       rst,
    output wire       uart_tx_pin,
    input  wire       uart_rx_pin,
    input  wire       uart_debug_pin,
    output wire       succ,
    output wire [2:0] pwm_o,
    inout  wire       iic_scl,
    inout  wire       iic_sda
);

    wire [`PWIDTH_O-1:0] tx_data;
    wire [`PWIDTH_I-1:0] rx_data;
    wire                  pwm_unused;

    tinyriscv_soc_top u_tinyriscv_soc_top(
        .clk(clk),
        .rst_ext_i(rst),
        .uart_tx_pin(uart_tx_pin),
        .uart_rx_pin(uart_rx_pin),
        .uart_debug_pin(uart_debug_pin),
        .succ(succ),
        .pwm_o({pwm_unused, pwm_o}),
        .iic_scl(iic_scl),
        .iic_sda(iic_sda),
        .tx_data_o(tx_data),
        .rx_data_i(rx_data)
    );

    exmem_top u_exmem_top(
        .clk(clk),
        .rst(~rst),
        .tx_data_i(tx_data),
        .rx_data_o(rx_data)
    );

endmodule
