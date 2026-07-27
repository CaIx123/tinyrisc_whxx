// 定义SCL时钟的不同状态，基于3位计数器cnt的值
`define SCL_POSEDGE (cnt==3'd0)   // SCL时钟上升沿
`define SCL_HIGH    (cnt==3'd1)   // SCL时钟高电平阶段
`define SCL_NEGEDGE (cnt==3'd2)   // SCL时钟下降沿
`define SCL_LOW     (cnt==3'd3)   // SCL时钟低电平阶段

module i2c(
    input wire clk,            // 输入系统时钟
    input wire rst_n,          // 低有效复位信号

    // CPU或主控接口信号
    input wire we_i,           // 写使能信号
    input wire[31:0] addr_i,   // 地址输入
    input wire[31:0] data_i,   // 写入数据
    output reg[31:0] data_o,   // 读出数据
    output reg read_data_ready_o, // 读取数据准备好标志
    input wire req_i,          // I2C操作请求信号

    output wire scl,           // I2C时钟线输出
    inout wire sda             // I2C数据线，双向
);

    // 设备地址寄存器及对应地址映射常量
    reg [31:0] device_addr;
    localparam DEV_ADDR = 4'h1;

    // 写数据寄存器及映射地址
    reg [31:0] write_data;
    localparam WR_DATA = 4'h2;

    // 读数据寄存器及映射地址
    reg [31:0] read_data;
    localparam RD_DATA = 4'h3;

    // 使能寄存器及映射地址
    reg [31:0] enable;
    localparam EN_REG = 4'h4;

    // 时钟分频寄存器及映射地址，用于产生I2C时钟频率
    reg [31:0] clk_div;
    localparam CLK_DIV = 4'h5;

    // 产生分频时钟各关键时刻的计数阈值，辅助生成SCL波形
    wire [15:0] div_q1 = (clk_div >> 2) - 1;        // clk_div/4 -1
    wire [15:0] div_q2 = (clk_div >> 1) - 1;        // clk_div/2 -1
    wire [15:0] div_q3 = div_q1 + div_q2 - 1;       // clk_div*3/4 -1
    wire [15:0] div_q4 = clk_div - 1;                // clk_div -1

    // 临时存储发送的一个字节数据
    reg [7:0] temp_data;

    // 状态机状态定义
    localparam S_IDLE   = 4'd0,  // 空闲状态
               S_START  = 4'd1,  // 起始条件
               S_ADDR   = 4'd2,  // 发送设备地址
               S_ACK1   = 4'd3,  // 地址应答
               S_DATA1  = 4'd4,  // 接收数据第一字节
               S_ACK2   = 4'd5,  // 数据应答
               S_DATA2  = 4'd6,  // 接收数据第二字节
               S_NACK   = 4'd7,  // 非应答，准备停止
               S_STOP   = 4'd8;  // 停止条件

    reg [3:0] state;       // 当前状态
    reg sda_val;           // SDA线上输出的数据值
    reg sda_dir;           // SDA线驱动方向，1输出，0高阻
    reg [3:0] bit_cnt;     // 位计数器，用于跟踪传输的比特位数

    reg [2:0] cnt;         // 3位计数，用于SCL时钟状态控制
    reg [15:0] clk_cnt;    // 时钟分频计数器
    reg scl_val;           // SCL信号内部状态

    // 时钟分频计数器，用于产生I2C时钟周期
    always @(posedge clk) begin
        if (!rst_n)
            clk_cnt <= 16'd0;
        else if (clk_cnt == (clk_div - 1))
            clk_cnt <= 0;
        else
            clk_cnt <= clk_cnt + 1;
    end

    // 根据分频计数产生SCL的阶段计数cnt，用于驱动SCL波形
    always @(posedge clk) begin
        if (!rst_n)
            cnt <= 3'd5;   // 无效状态
        else begin
            case (clk_cnt)
                div_q1: cnt <= 3'd1;  // SCL高电平起始
                div_q2: cnt <= 3'd2;  // SCL下降沿
                div_q3: cnt <= 3'd3;  // SCL低电平
                div_q4: cnt <= 3'd0;  // SCL上升沿
                default: cnt <= 3'd5; // 其他时间无效
            endcase
        end
    end

    // 根据cnt生成SCL实际信号，1或0
    always @(posedge clk) begin
        if (!rst_n)
            scl_val <= 1;
        else if (cnt == 3'd0)    // SCL上升沿，保持高电平
            scl_val <= 1;
        else if (cnt == 3'd2)    // SCL下降沿，拉低SCL
            scl_val <= 0;
    end

    // SCL输出逻辑：
    // 空闲和停止状态时SCL拉高，否则输出scl_val产生时钟
    assign scl = (state == S_IDLE || state == S_STOP) ? 1 : scl_val;

    // SDA双向线驱动逻辑：
    // sda_dir=1时驱动sda_val，否则sda处于高阻（允许外部拉高或读入）
    assign sda = sda_dir ? sda_val : 1'bz;

    // I2C状态机，处理起始、地址、数据、应答及停止流程
    always @(posedge clk) begin
        if (!rst_n) begin
            // 复位状态初始化
            state <= S_IDLE;
            sda_val <= 1;       // SDA默认高电平
            sda_dir <= 0;       // SDA线默认高阻
            bit_cnt <= 0;
            read_data_ready_o <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    sda_dir <= 1;      // 主控驱动SDA
                    sda_val <= 1;      // SDA拉高，空闲状态
                    read_data_ready_o <= 0;
                    // 当收到请求或使能时，加载设备地址，准备开始通信
                    if (req_i || enable[0]) begin
                        temp_data <= device_addr[7:0]; // 取设备地址低8位
                        state <= S_START;              // 转入起始状态
                    end
                end
                S_START: begin
                    // 起始条件：SDA从高拉到低，要求SCL高电平期间拉低SDA
                    if (`SCL_HIGH) begin
                        sda_val <= 0;
                        state <= S_ADDR;
                        bit_cnt <= 0;
                    end
                end
                S_ADDR: begin
                    // 发送设备地址的每一位，数据在SCL低电平期间改变
                    if (`SCL_LOW) begin
                        if (bit_cnt == 8) begin
                            bit_cnt <= 0;
                            sda_val <= 1;   // 释放SDA准备接收ACK
                            sda_dir <= 0;   // SDA置高阻由从机驱动ACK
                            state <= S_ACK1;
                        end else begin
                            sda_val <= temp_data[7 - bit_cnt];  // 按位发送地址
                            bit_cnt <= bit_cnt + 1;
                        end
                    end
                end
                S_ACK1: begin
                    // 监听从机ACK信号，sda_val为输入的sda线电平
                    // 若ACK拉低且SCL高，或者检测到SCL下降沿，进入接收数据状态
                    if ((!sda_val && `SCL_HIGH) || `SCL_NEGEDGE)
                        state <= S_DATA1;
                end
                S_DATA1: begin
                    // 接收第一个字节的数据，在SCL高电平时采样SDA
                    if (`SCL_HIGH) begin
                        bit_cnt <= bit_cnt + 1;
                        read_data[15 - bit_cnt] <= sda;  // 从高位开始接收
                    end else if (`SCL_NEGEDGE && bit_cnt == 8) begin
                        bit_cnt <= 0;
                        sda_dir <= 1;   // 主控驱动SDA准备发送ACK
                        sda_val <= 1;   // 默认释放SDA
                        state <= S_ACK2;
                    end
                end
                S_ACK2: begin
                    // 主控在SCL低电平时拉低SDA发ACK
                    if (`SCL_LOW)
                        sda_val <= 0;
                    else if (`SCL_NEGEDGE) begin
                        state <= S_DATA2;
                        sda_dir <= 0;   // SDA高阻，等待从机发送第二字节数据
                        sda_val <= 1;   // 释放SDA
                    end
                end
                S_DATA2: begin
                    // 接收第二字节数据，逻辑同DATA1
                    if (`SCL_HIGH) begin
                        bit_cnt <= bit_cnt + 1;
                        read_data[7 - bit_cnt] <= sda;   // 低字节部分接收
                    end else if (`SCL_LOW && bit_cnt == 8) begin
                        bit_cnt <= 0;
                        sda_dir <= 1;   // 主控驱动SDA准备发送NACK
                        sda_val <= 1;   // 默认释放SDA
                        state <= S_NACK;
                    end
                end
                S_NACK: begin
                    // 发送NACK，通知从机停止发送
                    if (`SCL_LOW) begin
                        sda_val <= 0;  // 拉低SDA发送NACK信号
                        state <= S_STOP;
                        // 对接收数据做简单处理，只保留有效位
                        read_data <= {8'b0, read_data[14:7]};
                        read_data_ready_o <= 1;  // 数据接收完成，拉高标志
                    end
                end
                S_STOP: begin
                    // 停止条件，SDA在SCL高电平时从低拉高
                    if (`SCL_HIGH) begin
                        sda_val <= 1;  // 释放SDA线
                        state <= S_IDLE; // 返回空闲状态，等待下次请求
                    end
                end
                default: state <= S_IDLE;
            endcase
        end
    end

    // 寄存器写入逻辑，支持CPU写操作修改设备地址、写数据、使能寄存器和时钟分频值
    always @(posedge clk) begin
        if (!rst_n) begin
            device_addr <= 32'h91;  // 复位时设备地址默认0x91
            write_data <= 0;
            enable <= 0;
            clk_div <= 500;         // 默认时钟分频值，控制I2C时钟频率
        end else if (we_i) begin
            case (addr_i[19:16])
                DEV_ADDR: device_addr <= data_i;
                WR_DATA: write_data <= data_i;
                EN_REG: enable <= data_i;
                CLK_DIV: clk_div <= data_i;
            endcase
        end
    end

    // 读取寄存器逻辑，支持CPU读出寄存器值
    always @(*) begin
        if (!rst_n)
            data_o = 0;
        else begin
            case (addr_i[19:16])
                DEV_ADDR: data_o = device_addr;
                WR_DATA: data_o = write_data;
                RD_DATA: data_o = read_data;
                EN_REG: data_o = enable;
                CLK_DIV: data_o = clk_div;
                default: data_o = 0;
            endcase
        end
    end

endmodule
