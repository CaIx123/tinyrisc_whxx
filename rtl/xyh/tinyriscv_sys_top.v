`include "./core/defines.v"
`include "tiny_macro.v"

// 系统最顶层封装
// 实例化tinyriscv_soc_top(处理器+片上外设)和exmem_top(外部存储子系统)
// 处理IIC顶层三态IOBUF(仿真用assign，板级用Xilinx IOBUF原语)
// PWM输出在高位补pwm_float_o信号
module tinyriscv_sys_top(

    input wire clk,                          // 时钟
    input wire rst,                          // 复位(高有效)

    output wire uart_tx_pin,                 // UART发送引脚
    input wire uart_rx_pin,                  // UART接收引脚
    input wire uart_debug_pin,               // UART调试下载引脚
    output wire succ,                        // 测试成功指示(低有效)

    output wire[2:0] pwm_o,                  // PWM输出(3路)
    inout wire iic_scl,                      // IIC SCL(开漏)
    inout wire iic_sda                       // IIC SDA(开漏)

    );

    wire[`PWIDTH_O-1:0] tx_data;
    wire[`PWIDTH_I-1:0] rx_data;
    wire pwm_float_o;
    wire iic_scl_i;
    wire iic_sda_i;
    wire iic_scl_oe;
    wire iic_sda_oe;

`ifdef sim
    assign iic_scl = iic_scl_oe ? 1'b0 : 1'bz;
    assign iic_sda = iic_sda_oe ? 1'b0 : 1'bz;
    assign iic_scl_i = iic_scl;
    assign iic_sda_i = iic_sda;
`else
    IOBUF u_iic_scl_iobuf(
        .I(1'b0),
        .T(~iic_scl_oe),
        .O(iic_scl_i),
        .IO(iic_scl)
    );

    IOBUF u_iic_sda_iobuf(
        .I(1'b0),
        .T(~iic_sda_oe),
        .O(iic_sda_i),
        .IO(iic_sda)
    );
`endif

    tinyriscv_soc_top u_tinyriscv_soc_top(
        .clk(clk),
        .rst_ext_i(rst),

        .uart_tx_pin(uart_tx_pin),
        .uart_rx_pin(uart_rx_pin),
        .uart_debug_pin(uart_debug_pin),
        .succ(succ),

        .pwm_o({pwm_float_o, pwm_o}),
        .iic_scl_i(iic_scl_i),
        .iic_sda_i(iic_sda_i),
        .iic_scl_oe_o(iic_scl_oe),
        .iic_sda_oe_o(iic_sda_oe),

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
