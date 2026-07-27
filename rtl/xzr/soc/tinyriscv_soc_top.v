`include "../core/defines.v"

// tinyriscv soc顶层模块
module tinyriscv_soc_top(

    input wire clk,
    input wire rst,
    
    output reg succ,         // 测试是否成功信号

    input wire uart_debug_pin, // 串口下载使能引脚

    output wire uart_tx_pin, // UART发送引脚
    input wire uart_rx_pin,  // UART接收引脚
    
    output wire[2:0] PWM_o,      // PWM输出引脚

    output wire io_scl,     // I2C SCL引脚
    inout wire io_sda      // I2C SDA引脚

    );

    reg over;

    // master 0 interface
    wire[`MemAddrBus] m0_addr_i;
    wire[`MemBus] m0_data_i;
    wire[`MemBus] m0_data_o;
    wire m0_req_i;
    wire m0_we_i;
    wire m0_ack_o;

    // master 1 interface
    wire[`MemAddrBus] m1_addr_i;
    wire[`MemBus] m1_data_i;
    wire[`MemBus] m1_data_o;
    wire m1_req_i;
    wire m1_we_i;

    // master 3 interface
    wire[`MemAddrBus] m3_addr_i;
    wire[`MemBus] m3_data_i;
    wire[`MemBus] m3_data_o;
    wire m3_req_i;
    wire m3_we_i;

    // slave 0 interface
    wire[`MemAddrBus] s0_addr_o;
    wire[`MemBus] s0_data_o;
    wire[`MemBus] s0_data_i;
    wire s0_we_o;
    wire s0_req_o;

    // slave 1 interface
    wire[`MemAddrBus] s1_addr_o;
    wire[`MemBus] s1_data_o;
    wire[`MemBus] s1_data_i;
    wire s1_we_o;


    // slave 3 interface
    wire[`MemAddrBus] s3_addr_o;
    wire[`MemBus] s3_data_o;
    wire[`MemBus] s3_data_i;
    wire s3_we_o;

    // slave 4 interface
    wire[`MemAddrBus] s4_addr_o;
    wire[`MemBus] s4_data_o;
    wire[`MemBus] s4_data_i;
    wire s4_we_o;

    // slave 5 interface
    wire[`MemAddrBus] s5_addr_o;
    wire[`MemBus] s5_data_o;
    wire[`MemBus] s5_data_i;
    wire s5_we_o;

    // slave 6 interface
    wire[`MemAddrBus] s6_addr_o;
    wire[`MemBus] s6_data_o;
    wire[`MemBus] s6_data_i;
    wire s6_we_o;

    // slave 7 interface
    wire[`MemAddrBus] s7_addr_o;
    wire[`MemBus] s7_data_o;
    wire[`MemBus] s7_data_i;
    wire s7_we_o;
    wire s7_req_o;
    wire s7_ack_i;

    // rib
    wire rib_hold_flag_o;

    // tinyriscv
    wire[`INT_BUS] int_flag;

    wire [15:0] temper;
    wire en_tem;


    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            over <= 1'b1;
            succ <= 1'b1;
        end else begin
            over <= ~u_tinyriscv.u_regs.regs[26];  // when = 1, run over
            succ <= ~u_tinyriscv.u_regs.regs[27];  // when = 1, run succ, otherwise fail
        end
    end

    // tinyriscv处理器核模块例化
    tinyriscv u_tinyriscv(
        .clk(clk),
        .rst(rst),
        .rib_ex_addr_o(m0_addr_i),
        .rib_ex_data_i(m0_data_o),
        .rib_ex_data_o(m0_data_i),
        .rib_ex_req_o(m0_req_i),
        .rib_ex_we_o(m0_we_i),
        .rib_ex_ack_i(m0_ack_o),

        .rib_pc_addr_o(m1_addr_i),
        .rib_pc_data_i(m1_data_o),
        .rib_hold_flag_i(rib_hold_flag_o)

    );

    uart_top uart_0(
        .clk(clk),
        .rst(rst),
        .we_i(s3_we_o),
        .addr_i(s3_addr_o),
        .data_i(s3_data_o),
        .data_o(s3_data_i),
        .tx_pin(uart_tx_pin),
        .rx_pin(uart_rx_pin)
    );

    // rib模块例化
    rib u_rib(
        .clk(clk),
        .rst(rst),

        // master 0 interface
        .m0_addr_i(m0_addr_i),
        .m0_data_i(m0_data_i),
        .m0_data_o(m0_data_o),
        .m0_req_i(m0_req_i),
        .m0_we_i(m0_we_i),
        .m0_ack_o(m0_ack_o),

        // master 1 interface
        .m1_addr_i(m1_addr_i),
        .m1_data_i(`ZeroWord),
        .m1_data_o(m1_data_o),
        .m1_req_i(`RIB_REQ),
        .m1_we_i(`WriteDisable),

        // master 2 interface (原 JTAG 内存访问主机接口，固定无效)
        .m2_addr_i(`ZeroWord),
        .m2_data_i(`ZeroWord),
        .m2_data_o(),
        .m2_req_i(`RIB_NREQ),
        .m2_we_i(`WriteDisable),

        // master 3 interface
        .m3_addr_i(m3_addr_i),
        .m3_data_i(m3_data_i),
        .m3_data_o(m3_data_o),
        .m3_req_i(m3_req_i),
        .m3_we_i(m3_we_i),

        // slave 0 interface
        .s0_addr_o(s0_addr_o),
        .s0_data_o(s0_data_o),
        .s0_data_i(s0_data_i),
        .s0_we_o(s0_we_o),
        .s0_req_o(s0_req_o),

        // slave 1 interface
        .s1_addr_o(),
        .s1_data_o(),
        .s1_data_i(`ZeroWord),
        .s1_we_o(),

        // slave 2 interface (原 timer0 接口，连接置空)
        .s2_addr_o(),
        .s2_data_o(),
        .s2_data_i(`ZeroWord),
        .s2_we_o(),

        // slave 3 interface
        .s3_addr_o(s3_addr_o),
        .s3_data_o(s3_data_o),
        .s3_data_i(s3_data_i),
        .s3_we_o(s3_we_o),

        // slave 4 interface
        .s4_addr_o(s4_addr_o),
        .s4_data_o(s4_data_o),
        .s4_data_i(s4_data_i),
        .s4_we_o(s4_we_o),

        // slave 5 interface
        .s5_addr_o(s5_addr_o),
        .s5_data_o(s5_data_o),
        .s5_data_i(s5_data_i),
        .s5_we_o(s5_we_o),

        // slave 6 interface
        .s6_addr_o(s6_addr_o),
        .s6_data_o(s6_data_o),
        .s6_data_i(s6_data_i),
        .s6_we_o(s6_we_o),

        // slave 7 interface
        .s7_addr_o(s7_addr_o),
        .s7_data_o(s7_data_o),
        .s7_data_i(s7_data_i),
        .s7_we_o(s7_we_o),
        .s7_req_o(s7_req_o),
        .s7_ack_i(s7_ack_i),

        .hold_flag_o(rib_hold_flag_o)
    );

    wire hold_from_bridge;
    wire [7:0] bridge_tx,bridge_rx;
    bridge u_bridge_chip(
        .clk(clk),
        .rst(rst),
        .addr_i(s0_addr_o),    // 接 rib 输出的 s0_addr
        .data_i(s0_data_o),    // 接 rib 输出的 s0_data
        .we_i(s0_we_o),        // 接 rib 输出的 s0_we
        .req_i(s0_req_o),      // 接 rib 输出的 s0_req
        .data_o(s0_data_i),    // 接给 rib 输入的 s0_data
        .hold_flag_o(hold_from_bridge), // 这个要接给 ctrl 模块
        // 外部 8-bit IO 引脚
        .tx_8bit(bridge_tx),
        .rx_8bit(bridge_rx)
    );

    wire [31:0] rom_data,ram_data,mem_addr,mem_wdata;
    wire ram_we,rom_we;
    bridge_fpga u_bridge_fpga(
        .clk(clk),
        .rst(rst),

        // ... 外部 8-bit IO 引脚
        .tx_8bit(bridge_rx),
        .rx_8bit(bridge_tx),

        //from RAM/ROM
        .rom_data(rom_data),
        .ram_data(ram_data),

        //to RAM/ROM
        .ram_we(ram_we),
        .rom_we(rom_we),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata)
    );

    // rom模块例化
    rom u_rom(
        .clk(clk),
        .rst(rst),
        .we_i(rom_we),
        .addr_i(mem_addr),
        .data_i(mem_wdata),
        .data_o(rom_data)
    );

    // ram模块例化
    ram u_ram(
        .clk(clk),
        .rst(rst),
        .we_i(ram_we),
        .addr_i(mem_addr),
        .data_i(mem_wdata),
        .data_o(ram_data)
    );

    //串口下载模块例化
    uart_debug u_uart_debug(
        .clk(clk),
        .rst(rst),
        .debug_en_i(uart_debug_pin),
        .req_o(m3_req_i),
        .mem_we_o(m3_we_i),
        .mem_addr_o(m3_addr_i),
        .mem_wdata_o(m3_data_i),
        .mem_rdata_i(m3_data_o)
    );


    wire PWM_temp;
    // pwm模块例化
    pwm pwm_0(
        .clk(clk),
        .rst(rst),
        .data_i(s6_data_o),
        .addr_i(s6_addr_o),
        .we_i(s6_we_o),
        .data_o(s6_data_i),
        .PWM_o({PWM_temp,PWM_o[2:0]})
    );

    
    i2c i2c_0(
        .clk(clk),
        .rst_n(rst),
        .data_i(s7_data_o),
        .addr_i(s7_addr_o),
        .we_i(s7_we_o),
        .data_o(s7_data_i),
        .scl(io_scl),
        .sda(io_sda),
        .read_data_ready_o(s7_ack_i),
        .req_i(s7_req_o)
    );


endmodule