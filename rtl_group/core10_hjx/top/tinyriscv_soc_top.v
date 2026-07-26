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
`include "../macros.v"

// tinyriscv soc顶层模块
module tinyriscv_soc_top(

    input wire clk,
    input wire rst_ext_i,

    output reg succ,         // 测试是否成功信号

    output wire uart_tx_pin, // UART发送引脚
    input wire uart_rx_pin,  // UART接收引脚

    input wire uart_debug_pin,

    output wire[3:0] PWM_out_pin,

    inout wire IIC_SDA_pin,
    output wire IIC_SCL_pin,

    output wire[`PWIDTH_O-1:0] bridge_tx_o,
    input wire[`PWIDTH_I-1:0] bridge_rx_i

    );

    // master 0 interface
    wire[31:0] m0_addr_i;
    wire[31:0] m0_data_i;
    wire[3:0] m0_sel_i;
    wire m0_req_vld_i;
    wire m0_rsp_rdy_i;
    wire m0_we_i;
    wire m0_req_rdy_o;
    wire m0_rsp_vld_o;
    wire[31:0] m0_data_o;

    // master 1 interface
    wire[31:0] m1_addr_i;
    wire[31:0] m1_data_i;
    wire[3:0] m1_sel_i;
    wire m1_req_vld_i;
    wire m1_rsp_rdy_i;
    wire m1_we_i;
    wire m1_req_rdy_o;
    wire m1_rsp_vld_o;
    wire[31:0] m1_data_o;

    // master 2 interface
    wire[31:0] m2_addr_i;
    wire[31:0] m2_data_i;
    wire[3:0] m2_sel_i;
    wire m2_req_vld_i;
    wire m2_rsp_rdy_i;
    wire m2_we_i;
    wire m2_req_rdy_o;
    wire m2_rsp_vld_o;
    wire[31:0] m2_data_o;

    // slave 0 interface
    wire[31:0] s0_data_i;
    wire s0_req_rdy_i;
    wire s0_rsp_vld_i;
    wire[31:0] s0_addr_o;
    wire[31:0] s0_data_o;
    wire[3:0] s0_sel_o;
    wire s0_req_vld_o;
    wire s0_rsp_rdy_o;
    wire s0_we_o;

    // slave 1 interface
    wire[31:0] s1_data_i;
    wire s1_req_rdy_i;
    wire s1_rsp_vld_i;
    wire[31:0] s1_addr_o;
    wire[31:0] s1_data_o;
    wire[3:0] s1_sel_o;
    wire s1_req_vld_o;
    wire s1_rsp_rdy_o;
    wire s1_we_o;

    // slave 2 interface (reserved)
    wire[31:0] s2_data_i;
    wire s2_req_rdy_i;
    wire s2_rsp_vld_i;
    wire[31:0] s2_addr_o;
    wire[31:0] s2_data_o;
    wire[3:0] s2_sel_o;
    wire s2_req_vld_o;
    wire s2_rsp_rdy_o;
    wire s2_we_o;

    // slave 3 interface
    wire[31:0] s3_data_i;
    wire s3_req_rdy_i;
    wire s3_rsp_vld_i;
    wire[31:0] s3_addr_o;
    wire[31:0] s3_data_o;
    wire[3:0] s3_sel_o;
    wire s3_req_vld_o;
    wire s3_rsp_rdy_o;
    wire s3_we_o;

    // slave 4 interface (unused, kept only for rib port compatibility)
    wire[31:0] s4_data_i;
    wire s4_req_rdy_i;
    wire s4_rsp_vld_i;
    wire[31:0] s4_addr_o;
    wire[31:0] s4_data_o;
    wire[3:0] s4_sel_o;
    wire s4_req_vld_o;
    wire s4_rsp_rdy_o;
    wire s4_we_o;

    // slave 5 interface (unused)
    wire[31:0] s5_data_i;
    wire s5_req_rdy_i;
    wire s5_rsp_vld_i;
    wire[31:0] s5_addr_o;
    wire[31:0] s5_data_o;
    wire[3:0] s5_sel_o;
    wire s5_req_vld_o;
    wire s5_rsp_rdy_o;
    wire s5_we_o;

    // slave 6 interface (PWM at 0x6000_0000)
    wire[31:0] s6_data_i;
    wire s6_req_rdy_i;
    wire s6_rsp_vld_i;
    wire[31:0] s6_addr_o;
    wire[31:0] s6_data_o;
    wire[3:0] s6_sel_o;
    wire s6_req_vld_o;
    wire s6_rsp_rdy_o;
    wire s6_we_o;

    // slave 7 interface (IIC at 0x7000_0000)
    wire[31:0] s7_data_i;
    wire s7_req_rdy_i;
    wire s7_rsp_vld_i;
    wire[31:0] s7_addr_o;
    wire[31:0] s7_data_o;
    wire[3:0] s7_sel_o;
    wire s7_req_vld_o;
    wire s7_rsp_rdy_o;
    wire s7_we_o;

    // tinyriscv
    wire rst_n;

    // deleted peripherals return zero immediately on access
    assign s2_data_i = 32'h0;
    assign s2_req_rdy_i = 1'b1;
    assign s2_rsp_vld_i = s2_req_vld_o;

    assign s4_data_i = 32'h0;
    assign s4_req_rdy_i = 1'b1;
    assign s4_rsp_vld_i = s4_req_vld_o;

    assign s5_data_i = 32'h0;
    assign s5_req_rdy_i = 1'b1;
    assign s5_rsp_vld_i = s5_req_vld_o;

    // 复位控制模块例化
    rst_ctrl u_rst_ctrl(
        .clk(clk),
        .rst_ext_i(rst_ext_i),
        .core_rst_n_o(rst_n)
    );

    // 低电平表示程序执行成功。软件将 x27 写为 1 后点亮成功指示。
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            succ <= 1'b1;
        end else begin
            succ <= ~u_tinyriscv_core.u_gpr_reg.regs[27];
        end
    end

    // tinyriscv处理器核模块例化
    tinyriscv_core u_tinyriscv_core(
        .clk(clk),
        .rst_n(rst_n),

        // 指令总线
        .ibus_addr_o(m0_addr_i),
        .ibus_data_i(m0_data_o),
        .ibus_data_o(m0_data_i),
        .ibus_we_o(m0_we_i),
        .ibus_sel_o(m0_sel_i),
        .ibus_req_valid_o(m0_req_vld_i),
        .ibus_req_ready_i(m0_req_rdy_o),
        .ibus_rsp_valid_i(m0_rsp_vld_o),
        .ibus_rsp_ready_o(m0_rsp_rdy_i),

        // 数据总线
        .dbus_addr_o(m1_addr_i),
        .dbus_data_i(m1_data_o),
        .dbus_data_o(m1_data_i),
        .dbus_we_o(m1_we_i),
        .dbus_sel_o(m1_sel_i),
        .dbus_req_valid_o(m1_req_vld_i),
        .dbus_req_ready_i(m1_req_rdy_o),
        .dbus_rsp_valid_i(m1_rsp_vld_o),
        .dbus_rsp_ready_o(m1_rsp_rdy_i),

        .debug_halt_i(uart_debug_pin)
    );

    // 片上bridge，替代原来的本地ROM/RAM
    bridge_rib u_bridge_rib(
        .clk(clk),
        .rst_n(rst_n),

        .s0_req_vld_i(s0_req_vld_o),
        .s0_rsp_rdy_i(s0_rsp_rdy_o),
        .s0_we_i(s0_we_o),
        .s0_addr_i(s0_addr_o),
        .s0_data_i(s0_data_o),
        .s0_sel_i(s0_sel_o),
        .s0_data_o(s0_data_i),
        .s0_req_rdy_o(s0_req_rdy_i),
        .s0_rsp_vld_o(s0_rsp_vld_i),

        .s1_req_vld_i(s1_req_vld_o),
        .s1_rsp_rdy_i(s1_rsp_rdy_o),
        .s1_we_i(s1_we_o),
        .s1_addr_i(s1_addr_o),
        .s1_data_i(s1_data_o),
        .s1_sel_i(s1_sel_o),
        .s1_data_o(s1_data_i),
        .s1_req_rdy_o(s1_req_rdy_i),
        .s1_rsp_vld_o(s1_rsp_vld_i),

        .tx_data_o(bridge_tx_o),
        .rx_data_i(bridge_rx_i)
    );

    // uart模块例化
    uart uart_0(
        .clk(clk),
        .rst_n(rst_n),
        .addr_i(s3_addr_o),
        .data_i(s3_data_o),
        .sel_i(s3_sel_o),
        .we_i(s3_we_o),
        .data_o(s3_data_i),
        .req_valid_i(s3_req_vld_o),
        .req_ready_o(s3_req_rdy_i),
        .rsp_valid_o(s3_rsp_vld_i),
        .rsp_ready_i(s3_rsp_rdy_o),
        .tx_pin(uart_tx_pin),
        .rx_pin(uart_rx_pin)
    );
    pwm u_pwm(
        .clk(clk),
        .rst_n(rst_n),
        .we_i(s6_we_o),
        .addr_i(s6_addr_o),
        .data_i(s6_data_o),
        .data_o(s6_data_i),
        .req_valid_i(s6_req_vld_o),
        .req_ready_o(s6_req_rdy_i),
        .rsp_valid_o(s6_rsp_vld_i),
        .rsp_ready_i(s6_rsp_rdy_o),
        .pwm_o(PWM_out_pin)
    );

    i2c u_iic(
        .clk(clk),
        .rst_n(rst_n),
        .we_i(s7_we_o),
        .addr_i(s7_addr_o),
        .data_i(s7_data_o),
        .data_o(s7_data_i),
        .req_valid_i(s7_req_vld_o),
        .req_ready_o(s7_req_rdy_i),
        .rsp_valid_o(s7_rsp_vld_i),
        .rsp_ready_i(s7_rsp_rdy_o),
        .scl(IIC_SCL_pin),
        .sda(IIC_SDA_pin)
    );

    uart_debug u_uart_debug(
        .clk(clk),
        .rst_n(rst_n),
        .debug_en_i(uart_debug_pin),
        .req_valid_o(m2_req_vld_i),
        .req_ready_i(m2_req_rdy_o),
        .rsp_valid_i(m2_rsp_vld_o),
        .rsp_ready_o(m2_rsp_rdy_i),
        .mem_we_o(m2_we_i),
        .mem_addr_o(m2_addr_i),
        .mem_wdata_o(m2_data_i),
        .mem_sel_o(m2_sel_i),
        .mem_rdata_i(m2_data_o)
    );

    // rib总线模块例化
    rib u_rib(
        .clk(clk),
        .rst_n(rst_n),

        // master 0 interface
        .m0_addr_i(m0_addr_i),
        .m0_data_i(m0_data_i),
        .m0_sel_i(m0_sel_i),
        .m0_req_vld_i(m0_req_vld_i),
        .m0_rsp_rdy_i(m0_rsp_rdy_i),
        .m0_we_i(m0_we_i),
        .m0_req_rdy_o(m0_req_rdy_o),
        .m0_rsp_vld_o(m0_rsp_vld_o),
        .m0_data_o(m0_data_o),

        // master 1 interface
        .m1_addr_i(m1_addr_i),
        .m1_data_i(m1_data_i),
        .m1_sel_i(m1_sel_i),
        .m1_req_vld_i(m1_req_vld_i),
        .m1_rsp_rdy_i(m1_rsp_rdy_i),
        .m1_we_i(m1_we_i),
        .m1_req_rdy_o(m1_req_rdy_o),
        .m1_rsp_vld_o(m1_rsp_vld_o),
        .m1_data_o(m1_data_o),

        // master 2 interface
        .m2_addr_i(m2_addr_i),
        .m2_data_i(m2_data_i),
        .m2_sel_i(m2_sel_i),
        .m2_req_vld_i(m2_req_vld_i),
        .m2_rsp_rdy_i(m2_rsp_rdy_i),
        .m2_we_i(m2_we_i),
        .m2_req_rdy_o(m2_req_rdy_o),
        .m2_rsp_vld_o(m2_rsp_vld_o),
        .m2_data_o(m2_data_o),

        // slave 0 interface
        .s0_data_i(s0_data_i),
        .s0_req_rdy_i(s0_req_rdy_i),
        .s0_rsp_vld_i(s0_rsp_vld_i),
        .s0_addr_o(s0_addr_o),
        .s0_data_o(s0_data_o),
        .s0_sel_o(s0_sel_o),
        .s0_req_vld_o(s0_req_vld_o),
        .s0_rsp_rdy_o(s0_rsp_rdy_o),
        .s0_we_o(s0_we_o),

        // slave 1 interface
        .s1_data_i(s1_data_i),
        .s1_req_rdy_i(s1_req_rdy_i),
        .s1_rsp_vld_i(s1_rsp_vld_i),
        .s1_addr_o(s1_addr_o),
        .s1_data_o(s1_data_o),
        .s1_sel_o(s1_sel_o),
        .s1_req_vld_o(s1_req_vld_o),
        .s1_rsp_rdy_o(s1_rsp_rdy_o),
        .s1_we_o(s1_we_o),

        // slave 3 interface
        .s3_data_i(s3_data_i),
        .s3_req_rdy_i(s3_req_rdy_i),
        .s3_rsp_vld_i(s3_rsp_vld_i),
        .s3_addr_o(s3_addr_o),
        .s3_data_o(s3_data_o),
        .s3_sel_o(s3_sel_o),
        .s3_req_vld_o(s3_req_vld_o),
        .s3_rsp_rdy_o(s3_rsp_rdy_o),
        .s3_we_o(s3_we_o),

        // slave 6 interface
        .s6_data_i(s6_data_i),
        .s6_req_rdy_i(s6_req_rdy_i),
        .s6_rsp_vld_i(s6_rsp_vld_i),
        .s6_addr_o(s6_addr_o),
        .s6_data_o(s6_data_o),
        .s6_sel_o(s6_sel_o),
        .s6_req_vld_o(s6_req_vld_o),
        .s6_rsp_rdy_o(s6_rsp_rdy_o),
        .s6_we_o(s6_we_o),

        // slave 7 interface
        .s7_data_i(s7_data_i),
        .s7_req_rdy_i(s7_req_rdy_i),
        .s7_rsp_vld_i(s7_rsp_vld_i),
        .s7_addr_o(s7_addr_o),
        .s7_data_o(s7_data_o),
        .s7_sel_o(s7_sel_o),
        .s7_req_vld_o(s7_req_vld_o),
        .s7_rsp_rdy_o(s7_rsp_rdy_o),
        .s7_we_o(s7_we_o)
    );

endmodule
