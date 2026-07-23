/*
 Copyright 2020 Blue Liang, liangkangnan@163.com

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

`include "../core/defines.v"
`include "../perips/tiny_macro.v"

// tinyriscv soc + fpga external memory top level module for FPGA board testing
module tinyriscv_soc_fpga_top(

    input wire clk,
    input wire rst_ext_i,

    output wire succ,         // 测试是坦戝功信坷

    output wire uart_tx_pin, // UART坑�?�引�??????
    input wire uart_rx_pin,  // UART接收引脚

    input wire uart_debug_pin,

    output wire[3:0] PWM_out_pin,

    inout wire IIC_SDA_pin,
    output wire IIC_SCL_pin

    );
    

    // Internal signals connecting soc to fpga external memory
    wire[`PWIDTH_O-1:0] bridge_tx;
    wire[`PWIDTH_I-1:0] bridge_rx;

    // tinyriscv SoC顶层模块例化
    tinyriscv_soc_top u_soc_top(
        .clk(clk),
        .rst_ext_i(rst_ext_i),
        .succ(succ),
        .uart_tx_pin(uart_tx_pin),
        .uart_rx_pin(uart_rx_pin),
        .uart_debug_pin(uart_debug_pin),
        .PWM_out_pin(PWM_out_pin),
        .IIC_SDA_pin(IIC_SDA_pin),
        .IIC_SCL_pin(IIC_SCL_pin),
        .bridge_tx_o(bridge_tx),
        .bridge_rx_i(bridge_rx)
    );

    // FPGA外部存储（ROM + RAM）顶层模块例�??????
    FPGA_top u_fpga_top(
        .clk(clk),
        .rst_n(rst_ext_i),  
        .tx_data_i(bridge_tx),
        .rx_data_o(bridge_rx)
    );
    
    
    

endmodule
