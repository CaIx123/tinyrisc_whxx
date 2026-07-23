`include "../core/defines.v"
`include "../tiny_macro.v"

// SoC主体顶层模块
// 负责：复位控制(rst_ctrl)、处理器核(tinyriscv_core)、RIB总线互联
// 挂接UART/PWM/IIC/uart_debug/rib_bridge等外设
// x26与x27通过寄存器打一拍后形成succ测试完成信号
// uart_debug_pin上升沿产生pc_rst_pulse用于烧录完成后重启IFU
module tinyriscv_soc_top(

    input wire clk,                          // 时钟
    input wire rst_ext_i,                    // 外部复位输入

    output wire uart_tx_pin,                 // UART发送引脚
    input wire uart_rx_pin,                  // UART接收引脚
    input wire uart_debug_pin,               // UART调试下载引脚
    output wire succ,                        // 测试成功指示(低有效)

    output wire[3:0] pwm_o,                  // PWM输出(4路)
    input wire iic_scl_i,                    // IIC SCL输入
    input wire iic_sda_i,                    // IIC SDA输入
    output wire iic_scl_oe_o,                // IIC SCL输出使能(开漏)
    output wire iic_sda_oe_o,                // IIC SDA输出使能(开漏)

    output wire[`PWIDTH_O-1:0] tx_data_o,    // 片外串行发送数据
    input wire[`PWIDTH_I-1:0] rx_data_i      // 片外串行接收数据

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

    // master 3 interface
    wire[31:0] m3_addr_i;
    wire[31:0] m3_data_i;
    wire[3:0] m3_sel_i;
    wire m3_req_vld_i;
    wire m3_rsp_rdy_i;
    wire m3_we_i;
    wire m3_req_rdy_o;
    wire m3_rsp_vld_o;
    wire[31:0] m3_data_o;

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

    // slave 2 interface
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

    // slave 4 interface
    wire[31:0] s4_data_i;
    wire s4_req_rdy_i;
    wire s4_rsp_vld_i;
    wire[31:0] s4_addr_o;
    wire[31:0] s4_data_o;
    wire[3:0] s4_sel_o;
    wire s4_req_vld_o;
    wire s4_rsp_rdy_o;
    wire s4_we_o;
    // tinyriscv
    wire rst_n;
    wire[31:0] core_x26;
    wire[31:0] core_x27;
    reg succ_r;
    reg uart_debug_pin_r;
    wire pc_rst_pulse;

    // 复位控制模块例化
    rst_ctrl u_rst_ctrl(
        .clk(clk),
        .rst_ext_i(rst_ext_i),
        .rst_jtag_i(1'b0),
        .core_rst_n_o(rst_n),
        .jtag_rst_n_o()
    );

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            succ_r <= 32'h0;
        end else begin
            succ_r <= core_x26[0] & core_x27[0];
        end
    end

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_debug_pin_r <= 1'b1;
        end else begin
            uart_debug_pin_r <= uart_debug_pin;
        end
    end

    assign succ = ~succ_r;
    assign pc_rst_pulse = uart_debug_pin & (~uart_debug_pin_r);

    // tinyriscv处理器核模块例化
    tinyriscv_core u_tinyriscv_core(
        .clk(clk),
        .rst_n(rst_n),
        .pc_rst_i(pc_rst_pulse),

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
        .jtag_halt_i(~uart_debug_pin),
        .x26_o(core_x26),
        .x27_o(core_x27)
    );

    // 片外ROM/RAM桥接模块，替代片内ROM和RAM
    rib_bridge u_rib_bridge(
        .clk(clk),
        .rst(~rst_n),

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

        .tx_data_o(tx_data_o),
        .rx_data_i(rx_data_i)
    );

    // uart模块例化 (s2: 0x30000000)
    uart uart_0(
        .clk(clk),
        .rst_n(rst_n),
        .addr_i(s2_addr_o),
        .data_i(s2_data_o),
        .sel_i(s2_sel_o),
        .we_i(s2_we_o),
        .data_o(s2_data_i),
        .req_valid_i(s2_req_vld_o),
        .req_ready_o(s2_req_rdy_i),
        .rsp_valid_o(s2_rsp_vld_i),
        .rsp_ready_i(s2_rsp_rdy_o),
        .tx_pin(uart_tx_pin),
        .rx_pin(uart_rx_pin)
    );

    // pwm模块例化 (s3: 0x60000000)
    wire [3:0] pwm_temp;
    assign pwm_o = ~pwm_temp; // pwm模块输出为低电平有效，外部需要取反使用
    pwm pwm_0(
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
        .pwm_o(pwm_temp)
    );

    // iic模块例化 (s4: 0x70000000)
    iic iic_0(
        .clk(clk),
        .rst_n(rst_n),
        .addr_i(s4_addr_o),
        .data_i(s4_data_o),
        .sel_i(s4_sel_o),
        .we_i(s4_we_o),
        .data_o(s4_data_i),
        .req_valid_i(s4_req_vld_o),
        .req_ready_o(s4_req_rdy_i),
        .rsp_valid_o(s4_rsp_vld_i),
        .rsp_ready_i(s4_rsp_rdy_o),
        .iic_scl_i(iic_scl_i),
        .iic_sda_i(iic_sda_i),
        .iic_scl_oe_o(iic_scl_oe_o),
        .iic_sda_oe_o(iic_sda_oe_o)
    );
    assign m2_addr_i = 32'h0;
    assign m2_data_i = 32'h0;
    assign m2_sel_i = 4'h0;
    assign m2_req_vld_i = 1'b0;
    assign m2_rsp_rdy_i = 1'b0;
    assign m2_we_i = 1'b0;


    uart_debug u_uart_debug(
        .clk(clk),
        .rst_n(rst_n),
        .debug_en_i(~uart_debug_pin),
        .req_valid_o(m3_req_vld_i),
        .req_ready_i(m3_req_rdy_o),
        .rsp_valid_i(m3_rsp_vld_o),
        .rsp_ready_o(m3_rsp_rdy_i),
        .mem_we_o(m3_we_i),
        .mem_addr_o(m3_addr_i),
        .mem_wdata_o(m3_data_i),
        .mem_sel_o(m3_sel_i),
        .mem_rdata_i(m3_data_o)
    );

    // rib总线模块例化
    rib #(
        .MASTER_NUM(4),
        .SLAVE_NUM(5)
    ) u_rib(
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

        // master 3 interface
        .m3_addr_i(m3_addr_i),
        .m3_data_i(m3_data_i),
        .m3_sel_i(m3_sel_i),
        .m3_req_vld_i(m3_req_vld_i),
        .m3_rsp_rdy_i(m3_rsp_rdy_i),
        .m3_we_i(m3_we_i),
        .m3_req_rdy_o(m3_req_rdy_o),
        .m3_rsp_vld_o(m3_rsp_vld_o),
        .m3_data_o(m3_data_o),

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

        // slave 2 interface
        .s2_data_i(s2_data_i),
        .s2_req_rdy_i(s2_req_rdy_i),
        .s2_rsp_vld_i(s2_rsp_vld_i),
        .s2_addr_o(s2_addr_o),
        .s2_data_o(s2_data_o),
        .s2_sel_o(s2_sel_o),
        .s2_req_vld_o(s2_req_vld_o),
        .s2_rsp_rdy_o(s2_rsp_rdy_o),
        .s2_we_o(s2_we_o),

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

        // slave 4 interface
        .s4_data_i(s4_data_i),
        .s4_req_rdy_i(s4_req_rdy_i),
        .s4_rsp_vld_i(s4_rsp_vld_i),
        .s4_addr_o(s4_addr_o),
        .s4_data_o(s4_data_o),
        .s4_sel_o(s4_sel_o),
        .s4_req_vld_o(s4_req_vld_o),
        .s4_rsp_rdy_o(s4_rsp_rdy_o),
        .s4_we_o(s4_we_o)
    );

endmodule

